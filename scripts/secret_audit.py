"""Fail closed before publication; reports contain paths and rule names, never secrets."""
import argparse
import base64
import io
import json
import pathlib
import re
import subprocess
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
RULES = {
    "development-reporter-token": re.compile(rb"\btenodev_[A-Za-z0-9_-]{40,}"),
    "provider-token": re.compile(rb"\bsk-[A-Za-z0-9_-]{24,}"),
    "github-token": re.compile(rb"\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,})"),
    "private-key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH |ENCRYPTED )?PRIVATE KEY-----"),
    "aws-key": re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"),
}
PRIVATE = re.compile(r"(?i)(?:^|/)(?:agents\.md|\.env(?:\..*)?|[^/]*(?:accounts|credentials|signing)[^/]*\.(?:json|properties)|[^/]*\.(?:pem|key|p12|pfx|jks|keystore|sqlite|db))$")
KNOWN = []
FINDINGS = set()
COUNTS = {"source_files": 0, "history_blobs": 0, "archive_entries": 0, "known_private_values": 0}

def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)

def load_private(paths):
    for value in paths:
        content = pathlib.Path(value).read_text(encoding="utf-8")
        for match in re.finditer(r"(?:AZURE_SPEECH_KEY|DEEPSEEK_API_KEY)\s*=\s*([A-Za-z0-9_-]{24,})", content):
            secret = match.group(1)
            KNOWN.extend([secret.encode(), secret.encode("utf-16le"), base64.b64encode(secret.encode())])
    COUNTS["known_private_values"] = len(set(KNOWN)) // 3

def scan(path, content):
    if PRIVATE.search(path): FINDINGS.add((path, "private-file"))
    for secret in KNOWN:
        if secret in content: FINDINGS.add((path, "known-local-provider-key"))
    # Generic patterns run on text; exact local values also run on native binaries.
    if b"\x00" not in content[:8192]:
        for name, pattern in RULES.items():
            if pattern.search(content): FINDINGS.add((path, name))

def archive(path, content, depth=0):
    scan(path, content)
    if depth > 3 or not zipfile.is_zipfile(io.BytesIO(content)): return
    with zipfile.ZipFile(io.BytesIO(content)) as bundle:
        for item in bundle.infolist():
            if item.is_dir(): continue
            if item.file_size > 1024**3:
                FINDINGS.add((path + "/" + item.filename, "archive-entry-too-large-to-audit")); continue
            COUNTS["archive_entries"] += 1
            data = bundle.read(item)
            name = path + "/" + item.filename
            if item.filename.lower().endswith((".zip", ".apk", ".ipa", ".aar", ".jar")):
                archive(name, data, depth + 1)
            else: scan(name, data)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--history", action="store_true")
    parser.add_argument("--private-values", action="append", default=[])
    parser.add_argument("--artifact", action="append", default=[])
    options = parser.parse_args()
    load_private(options.private_values)
    names = git("ls-files", "-z", "--cached", "--others", "--exclude-standard").split(b"\0")
    for item in set(names):
        if not item: continue
        name = item.decode("utf-8")
        file = ROOT / name
        if not file.is_file(): continue
        COUNTS["source_files"] += 1
        scan(name, file.read_bytes())
    if options.history:
        objects = {}
        for line in git("rev-list", "--objects", "--all").decode("utf-8").splitlines():
            pieces = line.split(" ", 1)
            if len(pieces) == 2: objects[pieces[0]] = pieces[1]
        proc = subprocess.Popen(["git","cat-file","--batch"],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
        try:
            for oid,name in objects.items():
                proc.stdin.write((oid + "\n").encode()); proc.stdin.flush()
                head = proc.stdout.readline().decode().split()
                size = int(head[2]); content = proc.stdout.read(size); proc.stdout.read(1)
                if head[1] == "blob":
                    COUNTS["history_blobs"] += 1
                    scan("history/" + oid[:12] + "/" + name, content)
        finally:
            proc.stdin.close(); proc.stdout.close(); proc.wait()
    for item in options.artifact:
        file = pathlib.Path(item)
        if not file.is_file(): raise SystemExit("Artifact missing: " + str(file))
        archive(file.name, file.read_bytes())
    print(json.dumps({"status": "blocked" if FINDINGS else "pass", **COUNTS,
        "findings":[{"path":path,"rule":rule} for path,rule in sorted(FINDINGS)]}, ensure_ascii=True, indent=2))
    raise SystemExit(1 if FINDINGS else 0)

if __name__ == "__main__": main()
