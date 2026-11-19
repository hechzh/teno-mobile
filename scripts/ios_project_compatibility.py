"""Emit the portable signing project in the Xcode 14 project format.

XcodeGen's xcodeVersion changes the upgrade marker, not its object schema.
Only our standalone, explicitly enumerated project is converted. A newly
introduced object type must be handled deliberately before it can be shipped.
"""
import argparse
import json
from pathlib import Path
import re

OBJECT_VERSION = 56
COMPATIBILITY_VERSION = 'Xcode 14.0'
SUPPORTED_OBJECTS = {
    'PBXBuildFile', 'PBXContainerItemProxy', 'PBXCopyFilesBuildPhase',
    'PBXFileReference', 'PBXFrameworksBuildPhase', 'PBXGroup',
    'PBXHeadersBuildPhase', 'PBXNativeTarget', 'PBXProject',
    'PBXResourcesBuildPhase', 'PBXSourcesBuildPhase', 'PBXTargetDependency',
    'PBXVariantGroup', 'XCBuildConfiguration', 'XCConfigurationList',
}


def check_shape(text):
    kinds = set(re.findall(r'\bisa = (\w+);', text))
    if kinds - SUPPORTED_OBJECTS:
        raise ValueError('Unsupported Xcode 14 project objects: ' + ', '.join(sorted(kinds - SUPPORTED_OBJECTS)))
    if text.count('isa = PBXProject;') != 1:
        raise ValueError('Expected exactly one PBXProject')
    for forbidden in ('FlutterNativeIntegration', 'flutter_integration.sh',
                      'FLUTTER_ROOT', '/Users/runner/', '/tmp/teno-xcode-relocated'):
        if forbidden in text:
            raise ValueError('Nonportable signing project: ' + forbidden)
    return kinds


def convert(path):
    text = path.read_text(encoding='utf-8')
    check_shape(text)
    text, count = re.subn(r'(?m)^(\s*)objectVersion = \d+;', rf'\g<1>objectVersion = {OBJECT_VERSION};', text)
    if count != 1:
        raise ValueError('Expected exactly one project objectVersion')
    text = re.sub(r'(?m)^\s*(?:preferredProjectObjectVersion|minimizedProjectReferenceProxies|compatibilityVersion) = [^;]+;\n', '', text)
    text = text.replace('isa = PBXProject;', f'isa = PBXProject;\n\t\t\tcompatibilityVersion = "{COMPATIBILITY_VERSION}";')
    text = re.sub(r'LastUpgradeCheck = \d+;', 'LastUpgradeCheck = 1430;', text)
    path.write_text(text, encoding='utf-8')
    return verify(path)


def verify(path):
    text = path.read_text(encoding='utf-8')
    kinds = check_shape(text)
    assert re.search(r'\bobjectVersion = 56;', text), 'Wrong project format'
    assert f'compatibilityVersion = "{COMPATIBILITY_VERSION}";' in text
    assert 'preferredProjectObjectVersion' not in text
    assert 'minimizedProjectReferenceProxies' not in text
    assert 'com.jwd.ZhiYan' in text and 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;' in text
    return {'object_version': OBJECT_VERSION, 'compatibility_version': COMPATIBILITY_VERSION,
            'object_types': sorted(kinds), 'source_shape_verified': True,
            'xcode_14_3_1_actual_build': 'pending recipient verification'}


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('project', type=Path)
    p.add_argument('--convert', action='store_true')
    args = p.parse_args()
    print(json.dumps(convert(args.project) if args.convert else verify(args.project), indent=2))
