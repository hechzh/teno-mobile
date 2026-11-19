"""Reuse verified framework bytes only when their shared UI source still matches."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def reuse(archive, expected_sha, output):
    with archive.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != expected_sha:
        raise ValueError('Source archive hash mismatch')
    verified = []
    with zipfile.ZipFile(archive) as bundle:
        roots = {n.split('/')[0] for n in bundle.namelist()}
        assert len(roots) == 1
        prefix = roots.pop() + '/'
        meta = json.loads(bundle.read(prefix + 'manifest.json'))
        assert meta['flutter'] == '3.47.9' and meta['app_ui_base'] == '0.9.0'
        for file in sorted((ROOT / 'shared-ui').rglob('*')):
            rel = file.relative_to(ROOT).as_posix()
            if not file.is_file() or not (rel.startswith(('shared-ui/lib/', 'shared-ui/assets/'))
                or rel in ('shared-ui/pubspec.yaml', 'shared-ui/pubspec.lock')):
                continue
            assert file.read_bytes() == bundle.read(prefix + rel), 'Shared UI changed: ' + rel
            verified.append(rel)
        archived_sources = {n[len(prefix):] for n in bundle.namelist()
            if n.startswith((prefix + 'shared-ui/lib/', prefix + 'shared-ui/assets/')) and not n.endswith('/')}
        assert archived_sources <= set(verified), 'A shared UI source was removed'
        assert len(verified) > 30
        hashes = {}
        for name in bundle.namelist():
            base = prefix + 'ios/Frameworks/'
            if not name.startswith(base) or name.endswith('/'):
                continue
            relative = Path(name[len(base):])
            assert '..' not in relative.parts and not relative.is_absolute()
            assert relative.parts[0] in ('App.xcframework', 'Flutter.xcframework')
            data = bundle.read(name)
            mode = (bundle.getinfo(name).external_attr >> 16) & 0o777
            hashes[relative.as_posix()] = hashlib.sha256(data).hexdigest()
            for mode in ('Release', 'Debug'):
                target = output / mode / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data)
                target.chmod(mode or 0o644)
    result = {'source_archive_sha256': digest, 'source_commit': meta['commit'],
              'shared_ui_files_equal': len(verified), 'framework_files': hashes,
              'flutter_recompiled': False}
    (output / 'reuse-evidence.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k != 'framework_files'}, indent=2))


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('archive', type=Path)
    p.add_argument('--sha256', required=True)
    p.add_argument('--output', type=Path, default=ROOT / 'ios/build/frameworks')
    args = p.parse_args()
    reuse(args.archive, args.sha256, args.output)
