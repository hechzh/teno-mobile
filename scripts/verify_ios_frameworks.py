"""Verify (and only if necessary repair) XCFramework wrapper signatures.

The Flutter engine ships ``Flutter.xcframework`` with Google's publisher
signature on the wrapper and on the inner slices
(``FLUTTER.IO LLC`` / team ``S8QB4VV633``).  Reassembling the container with
``xcodebuild -create-xcframework``, or editing its ``Info.plist``, destroys
that signature.

The packaging step keeps the publisher's container byte-for-byte when the
Debug simulator slice is identical to the Release simulator slice.  When a
slice really has to be replaced, the wrapper is re-signed ad hoc so the
handoff never contains an unsigned container, while every Flutter inner slice
must still carry Google's signature.
"""
import argparse
import hashlib
import json
import plistlib
import re
import subprocess
from pathlib import Path

GOOGLE_TEAM = 'S8QB4VV633'
GOOGLE_NAME = 'FLUTTER.IO LLC'
MODES = ('Release', 'Debug')
FRAMEWORKS = ('Flutter', 'App')


def codesign(args):
    return subprocess.run(['codesign'] + args, capture_output=True, text=True)


def display(path):
    result = codesign(['-dvvv', str(path)])
    text = (result.stdout + '\n' + result.stderr).strip()
    unsigned = 'code object is not signed at all' in text or result.returncode != 0
    team = re.search(r'^TeamIdentifier=(.+)$', text, re.M)
    identifier = re.search(r'^Identifier=(.+)$', text, re.M)
    authorities = [value.strip() for value in re.findall(r'^Authority=(.+)$', text, re.M)]
    return {
        'signed': not unsigned,
        'team_identifier': team.group(1).strip() if team else None,
        'identifier': identifier.group(1).strip() if identifier else None,
        'authorities': authorities,
        'publisher': (GOOGLE_NAME if team and team.group(1).strip() == GOOGLE_TEAM
                      else None),
    }


def verify(path):
    result = codesign(['--verify', '--strict', '--verbose=2', str(path)])
    return {
        'valid': result.returncode == 0,
        'output': (result.stdout + result.stderr).strip()[-2000:],
    }


def ad_hoc_sign(path):
    result = codesign(['--force', '--sign', '-', '--timestamp=none', str(path)])
    if result.returncode != 0:
        raise SystemExit('Ad-hoc signing failed for ' + str(path) + '\n'
                         + result.stdout + result.stderr)


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def slices(container):
    info = plistlib.loads((container / 'Info.plist').read_bytes())
    rows = []
    for library in info.get('AvailableLibraries', []):
        framework = container / library['LibraryIdentifier'] / library['LibraryPath']
        framework_info = plistlib.loads((framework / 'Info.plist').read_bytes())
        binary = framework / framework_info['CFBundleExecutable']
        if not binary.is_file():
            raise SystemExit('Missing framework binary: ' + str(binary))
        rows.append({
            'identifier': library['LibraryIdentifier'],
            'platform': library.get('SupportedPlatform'),
            'variant': library.get('SupportedPlatformVariant', 'device'),
            'framework': str(framework.relative_to(container)),
            'binary_sha256': digest(binary),
            'signature': display(binary),
            'verification': verify(binary),
        })
    return rows


def inspect(container):
    return {
        'wrapper': {
            'signature': display(container),
            'verification': verify(container),
        },
        'slices': slices(container),
    }


def ensure(container, name, repair=True):
    """Return signature evidence, repairing only an unsigned/invalid wrapper.

    ``repair=False`` is used when checking the already packaged zip, so a
    broken handoff cannot pass by being silently re-signed after extraction.
    """
    entry = inspect(container)
    entry['name'] = name
    repaired = False
    if not entry['wrapper']['verification']['valid']:
        if not repair:
            raise SystemExit('XCFramework wrapper is not validly signed: '
                             + str(container))
        ad_hoc_sign(container)
        repaired = True
        entry = inspect(container)
        entry['name'] = name
    if not entry['wrapper']['verification']['valid']:
        raise SystemExit('XCFramework wrapper still fails codesign --verify: ' + str(container))
    entry['wrapper_repaired_with_ad_hoc_signature'] = repaired
    entry['wrapper_publisher'] = entry['wrapper']['signature']['publisher']
    if name == 'Flutter':
        for row in entry['slices']:
            signature = row['signature']
            if signature['team_identifier'] != GOOGLE_TEAM:
                raise SystemExit(
                    f'Flutter slice {row["identifier"]} lost the Google signature: '
                    f'{signature["team_identifier"]!r} in {container}')
            if not row['verification']['valid']:
                raise SystemExit('Flutter slice failed verification: ' + row['identifier'])
    return entry


def verify_tree(root, repair=True):
    """Verify either a Release/Debug tree or a flat handoff Frameworks folder."""
    root = Path(root)
    evidence = {'google_team': GOOGLE_TEAM, 'google_publisher': GOOGLE_NAME,
                'root': str(root), 'frameworks': {}}
    nested = (root / 'Release').is_dir() and (root / 'Debug').is_dir()
    if nested:
        for mode in MODES:
            for name in FRAMEWORKS:
                container = root / mode / (name + '.xcframework')
                if not container.is_dir():
                    raise SystemExit('Missing XCFramework: ' + str(container))
                evidence['frameworks'][f'{mode}/{name}.xcframework'] = ensure(container, name, repair)
    else:
        for name in FRAMEWORKS:
            container = root / (name + '.xcframework')
            if not container.is_dir():
                raise SystemExit('Missing XCFramework: ' + str(container))
            evidence['frameworks'][name + '.xcframework'] = ensure(container, name, repair)
    return evidence


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--frameworks', type=Path, required=True,
                        help='Release/Debug tree or the handoff Frameworks folder')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--no-repair', action='store_true',
                        help='Fail on an unsigned wrapper instead of re-signing it')
    args = parser.parse_args()
    evidence = verify_tree(args.frameworks, repair=not args.no_repair)
    text = json.dumps(evidence, indent=2)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding='utf-8')
    print(text)


if __name__ == '__main__':
    main()
