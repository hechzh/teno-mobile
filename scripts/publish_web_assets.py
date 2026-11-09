"""Create a separate, immutable Git commit containing only public Web resources.

This does not push, change HEAD, merge main or touch other clients. Review the
reported commit and scan the archive before pushing the asset-only branch.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def create(build, branch, archive):
    if not branch.startswith('assets/teno-web-'):
        raise ValueError('Use a separate assets/teno-web-* branch')
    build = build.resolve()
    manifest = json.loads((build/'startup-assets.json').read_text())
    base = (build/manifest['base']).resolve()
    assert base.is_relative_to(build)
    files = {}
    for name, digest in manifest['files'].items():
        file = (base/name).resolve()
        assert file.is_relative_to(base) and file.is_file()
        data = file.read_bytes()
        assert hashlib.sha256(data).hexdigest() == digest
        files['bundle/'+name] = data
    files['README.txt'] = ('Immutable Teno Web application resources. No accounts, recordings or credentials.\n'
                          'Source: https://github.com/hechzh/teno-mobile\n'
                          'Use the exact commit SHA in CDN URLs. Licenses: bundle/assets/NOTICES and bundled font notices.\n').encode()
    for license in (ROOT/'shared-ui/assets/fonts').glob('*.txt'):
        files['licenses/'+license.name] = license.read_bytes()
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
        for name, data in sorted(files.items()): out.writestr(name, data)
    subprocess.run(['python', str(ROOT/'scripts/secret_audit.py'), '--artifact', str(archive)], cwd=ROOT, check=True)
    with tempfile.TemporaryDirectory(prefix='teno-asset-index-') as tmp:
        env = dict(os.environ, GIT_INDEX_FILE=str(Path(tmp)/'index'))
        def git(*args, data=None):
            return subprocess.check_output(['git', *args], input=data, cwd=ROOT, env=env).decode().strip()
        git('read-tree', '--empty')
        entries = []
        for name, data in sorted(files.items()):
            digest = git('hash-object', '-w', '--stdin', data=data)
            entries.append(f'100644 {digest}\t{name}\n')
        git('update-index', '--index-info', data=''.join(entries).encode())
        tree = git('write-tree')
        commit = git('commit-tree', tree, '-m', 'Immutable public resources for '+branch)
        # Fail rather than overwrite an existing publication branch.
        git('update-ref', 'refs/heads/'+branch, commit, '0'*40)
    result = {'branch':branch, 'commit':commit, 'source_bundle':manifest['base'],
              'files':len(files), 'bytes':sum(map(len, files.values())),
              'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest()}
    archive.with_suffix('.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--build', type=Path, default=ROOT/'web-client/build/web')
    parser.add_argument('--branch', required=True)
    parser.add_argument('--archive', type=Path, required=True)
    args = parser.parse_args()
    create(args.build, args.branch, args.archive)
