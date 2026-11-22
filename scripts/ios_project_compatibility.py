"""Validate the portable Xcode project shipped to recipients.

The handoff project must be machine independent and use a modern project
format that Xcode 26 and Xcode 27 open without an upgrade prompt.  XcodeGen
2.46 emits objectVersion 77 for ``options.projectFormat: xcode16_0``; the
Xcode 14 downgrade used by the earlier compatibility candidate is no longer
applied because Xcode 26 or later is now mandatory for App Store uploads.
"""
import argparse
import json
from pathlib import Path
import re

MINIMUM_OBJECT_VERSION = 77  # Xcode 16 project format (objectVersion 77)
MINIMUM_XCODE = '26.0'
SUPPORTED_OBJECTS = {
    'PBXBuildFile', 'PBXContainerItemProxy', 'PBXCopyFilesBuildPhase',
    'PBXFileReference', 'PBXFileSystemSynchronizedBuildFileExceptionSet',
    'PBXFileSystemSynchronizedRootGroup', 'PBXFrameworksBuildPhase', 'PBXGroup',
    'PBXHeadersBuildPhase', 'PBXNativeTarget', 'PBXProject',
    'PBXResourcesBuildPhase', 'PBXSourcesBuildPhase', 'PBXTargetDependency',
    'PBXVariantGroup', 'XCConfigurationList', 'XCBuildConfiguration',
}
FORBIDDEN = ('FlutterNativeIntegration', 'flutter_integration.sh',
             'FLUTTER_ROOT', '/Users/runner/', '/tmp/teno-xcode-relocated')


def check_shape(text):
    kinds = set(re.findall(r'\bisa = (\w+);', text))
    if kinds - SUPPORTED_OBJECTS:
        raise ValueError('Unsupported project objects: '
                         + ', '.join(sorted(kinds - SUPPORTED_OBJECTS)))
    if text.count('isa = PBXProject;') != 1:
        raise ValueError('Expected exactly one PBXProject')
    for forbidden in FORBIDDEN:
        if forbidden in text:
            raise ValueError('Nonportable signing project: ' + forbidden)
    return kinds


def verify(path):
    text = path.read_text(encoding='utf-8')
    kinds = check_shape(text)
    match = re.search(r'(?m)^\s*objectVersion = (\d+);', text)
    if not match:
        raise ValueError('Missing project objectVersion')
    version = int(match.group(1))
    if version < MINIMUM_OBJECT_VERSION:
        raise ValueError(
            f'Project format {version} is older than {MINIMUM_OBJECT_VERSION}; '
            'Xcode 26+ is required for this handoff')
    if 'com.jwd.ZhiYan' not in text or 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' not in text:
        raise ValueError('Project identity or deployment target changed')
    if 'LastUpgradeCheck = 2700;' not in text:
        raise ValueError('Expected LastUpgradeCheck = 2700 for Xcode 27')
    return {'object_version': version,
            'minimum_xcode': MINIMUM_XCODE,
            'format': 'Xcode 16 or newer (objectVersion 77+)',
            'object_types': sorted(kinds),
            'source_shape_verified': True,
            'recipient_build': 'pending recipient verification'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('project', type=Path)
    args = parser.parse_args()
    print(json.dumps(verify(args.project), indent=2))
