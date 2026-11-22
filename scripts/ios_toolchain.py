"""Select the installed Xcode that satisfies Apple's App Store SDK minimum.

Since 2026-04-28, uploads to App Store Connect must be built with Xcode 26 or
later and an iOS 26 SDK or later.  The project prefers Xcode 27 while keeping
26 as the hard floor, and records the exact toolchain used by CI.
"""
import argparse
import json
import os
import re
import subprocess
from pathlib import Path

APPLICATIONS = Path('/Applications')
MINIMUM_XCODE_MAJOR = 26
PREFERRED_XCODE_MAJOR = 27
MINIMUM_IOS_SDK_MAJOR = 26


def xcodebuild_version(developer: Path) -> dict:
    result = subprocess.run(
        [str(developer / 'usr/bin/xcodebuild'), '-version'],
        capture_output=True, text=True, check=True,
        env={**os.environ, 'DEVELOPER_DIR': str(developer)})
    match = re.search(r'Xcode\s+(\d+)\.(\d+)(?:\.(\d+))?', result.stdout)
    if not match:
        raise SystemExit('Could not read xcodebuild version: ' + result.stdout)
    build = re.search(r'Build version\s+(\S+)', result.stdout)
    return {
        'version': '.'.join(part for part in match.groups() if part),
        'major': int(match.group(1)),
        'minor': int(match.group(2)),
        'build': build.group(1) if build else None,
    }


def ios_sdk(developer: Path) -> dict:
    result = subprocess.run(
        [str(developer / 'usr/bin/xcodebuild'), '-showsdks'],
        capture_output=True, text=True, check=True,
        env={**os.environ, 'DEVELOPER_DIR': str(developer)})
    matches = re.findall(r'iphoneos(\d+)\.(\d+)', result.stdout)
    if not matches:
        raise SystemExit('No iPhoneOS SDK reported by xcodebuild -showsdks')
    major, minor = max((int(a), int(b)) for a, b in matches)
    return {'version': f'{major}.{minor}', 'major': major, 'minor': minor}


def macos_version() -> str:
    try:
        return subprocess.check_output(['sw_vers', '-productVersion'], text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return 'unknown'


def candidates():
    installed = [p for p in APPLICATIONS.glob('Xcode*.app')
                 if (p / 'Contents/Developer/usr/bin/xcodebuild').is_file()]
    if (APPLICATIONS / 'Xcode.app/Contents/Developer/usr/bin/xcodebuild').is_file():
        installed.append(APPLICATIONS / 'Xcode.app')
    return sorted(set(installed))


def select():
    best = None
    for app in candidates():
        developer = app / 'Contents/Developer'
        try:
            version = xcodebuild_version(developer)
            sdk = ios_sdk(developer)
        except (OSError, subprocess.CalledProcessError, SystemExit):
            continue
        if version['major'] < MINIMUM_XCODE_MAJOR:
            continue
        if sdk['major'] < MINIMUM_IOS_SDK_MAJOR:
            continue
        beta = '_beta' in app.name or 'beta' in app.name.lower()
        key = (version['major'], version['minor'], 0 if beta else 1)
        if best is None or key > best[0]:
            best = (key, developer, version, sdk)
    if best is None:
        raise SystemExit(
            f'No Xcode {MINIMUM_XCODE_MAJOR}+ with an iOS {MINIMUM_IOS_SDK_MAJOR}+ SDK '
            f'was found in {APPLICATIONS}.')
    _, developer, version, sdk = best
    if version['major'] < PREFERRED_XCODE_MAJOR:
        print(f'Warning: Xcode {PREFERRED_XCODE_MAJOR} is preferred; '
              f'selected Xcode {version["version"]}.', flush=True)
    return developer, version, sdk


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--github-env', action='store_true',
                        help='Append DEVELOPER_DIR to $GITHUB_ENV')
    parser.add_argument('--output', type=Path, default=Path('ios/build/toolchain.json'))
    args = parser.parse_args()

    developer, version, sdk = select()
    evidence = {
        'selected': str(developer),
        'xcode': version['version'],
        'xcode_build': version['build'],
        'ios_sdk': sdk['version'],
        'ios_sdk_major': sdk['major'],
        'macos': macos_version(),
        'minimum': {
            'xcode_major': MINIMUM_XCODE_MAJOR,
            'ios_sdk_major': MINIMUM_IOS_SDK_MAJOR,
        },
        'preferred_xcode_major': PREFERRED_XCODE_MAJOR,
        'app_store_sdk_requirement': 'Xcode 26 + iOS 26 SDK since 2026-04-28',
        'meets_requirement': (version['major'] >= MINIMUM_XCODE_MAJOR
                              and sdk['major'] >= MINIMUM_IOS_SDK_MAJOR),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(evidence, indent=2), encoding='utf-8')
    print(json.dumps(evidence, indent=2))
    if args.github_env:
        env_path = os.environ.get('GITHUB_ENV')
        if not env_path:
            raise SystemExit('--github-env requires $GITHUB_ENV')
        with open(env_path, 'a', encoding='utf-8') as stream:
            stream.write(f'DEVELOPER_DIR={developer}\n')


if __name__ == '__main__':
    main()
