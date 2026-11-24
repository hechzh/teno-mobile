#!/usr/bin/env python3
"""Build a versioned UI gallery manifest from Flutter-rendered screenshots.

Run the screenshot tests first, for example:

  TENO_PERSONAL_SCREENSHOTS=design-baseline/v0.9.4/screenshots/android \
  flutter test test/personal_test.dart test/jwd_recording_test.dart \
               test/device_mcp_090_test.dart

Then run this script with --version 0.9.4. It reuses the previous version's
page titles/descriptions and only re-binds screenshot paths and SHA-256 values.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'design-baseline'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def version_key(name):
    match = re.fullmatch(r'v(\d+(?:\.\d+)*)', name)
    return tuple(int(part) for part in match.group(1).split('.')) if match else ()


def latest_template(version):
    candidates = []
    for path in BASE.glob('v*/pages.json'):
        key = version_key(path.parent.name)
        if key and key < version_key('v' + version):
            candidates.append((key, path.parent))
    if not candidates:
        raise SystemExit('No previous gallery template found')
    return max(candidates, key=lambda item: item[0])[1]


def resolve(root, relative):
    direct = root / relative
    if direct.is_file():
        return direct, relative
    nested = root / 'screenshots' / 'android' / relative
    if nested.is_file():
        return nested, 'screenshots/android/' + relative
    raise SystemExit(f'Screenshot missing: {root / relative}')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--version', required=True)
    parser.add_argument('--template')
    parser.add_argument('--output', type=Path, help='Build-specific gallery directory')
    args = parser.parse_args()
    version = args.version
    root = args.output or BASE / f'v{version}'
    if not (root / 'screenshots' / 'android').is_dir():
        raise SystemExit(f'Run the Flutter screenshots first: {root}/screenshots/android')
    template = Path(args.template) if args.template else latest_template(version)
    pages = json.loads((template / 'pages.json').read_text(encoding='utf-8'))
    if isinstance(pages, dict):
        pages = pages['pages']
    manifest = []
    for page in pages:
        for variant in page.get('variants', []):
            path, relative = resolve(root, variant['screenshot'])
            variant['screenshot'] = relative
            variant['sha256'] = sha(path)
            manifest.append({'screenshot': relative, 'sha256': variant['sha256']})
        page['evidence'] = (
            f'Flutter 3.47.9 widget-test render from the {version} source with synthetic data; '
            'not a physical-device screenshot.'
        )
    (root / 'pages.json').write_text(
        json.dumps(pages, ensure_ascii=False, indent=2), encoding='utf-8'
    )
    (root / 'screenshot-manifest.json').write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8'
    )
    print(json.dumps({
        'version': version,
        'template': str(template.relative_to(ROOT)),
        'pages': len(pages),
        'screenshots': len(manifest),
    }, ensure_ascii=False))


if __name__ == '__main__':
    main()
