"""Create a relocatable, Xcode-only signing handoff from CI-built XCFrameworks."""
import argparse
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import zipfile
from pathlib import Path
from ios_metadata import metadata as ios_metadata
from ios_project_compatibility import convert as compatible_project

ROOT = Path(__file__).resolve().parents[1]


def prepare(frameworks: Path, output: Path) -> Path:
    identity = ios_metadata(); version = identity['version']; build = identity['build']; bundle_id = identity['bundle_id']
    folder = output / identity['source_name']
    folder.mkdir(parents=True, exist_ok=False)
    files = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT).decode().split('\0')
    for name in files:
        if not name or not (name.startswith('ios/') or name.startswith('shared-ui/')):
            continue
        source = ROOT / name
        if source.is_file():
            destination = folder / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
    for name in ['App', 'Flutter']:
        source = frameworks / 'Release' / (name + '.xcframework')
        if not source.is_dir():
            raise RuntimeError('Missing prebuilt framework: ' + name)
        shutil.copytree(source, folder / 'ios/Frameworks' / source.name, symlinks=True)
        # Flutter's release ios-framework output has a simulator stub without a
        # debug kernel. Pair the release device slice with the real Debug
        # simulator slice so this one portable project also runs in Simulator.
        target = folder / 'ios/Frameworks' / source.name
        # This is a new mixed container, rather than the publisher's original
        # XCFramework. Remove only the old container signature before changing
        # its manifest; the unmodified framework slices retain their signatures.
        if (target/'_CodeSignature').is_dir():
            subprocess.run(['codesign','--remove-signature',str(target)],check=True)
        info = plistlib.loads((target/'Info.plist').read_bytes())
        debug = frameworks/'Debug'/source.name
        debug_info = plistlib.loads((debug/'Info.plist').read_bytes())
        for library in debug_info['AvailableLibraries']:
            if library.get('SupportedPlatformVariant') != 'simulator':
                continue
            identifier = library['LibraryIdentifier']
            shutil.copytree(debug/identifier,target/identifier,symlinks=True,dirs_exist_ok=True)
            info['AvailableLibraries'] = [row for row in info['AvailableLibraries'] if row.get('SupportedPlatformVariant') != 'simulator']+[library]
        (target/'Info.plist').write_bytes(plistlib.dumps(info))
        if name == 'App':
            assert list(target.glob('*/App.framework/flutter_assets/kernel_blob.bin')), 'Missing runnable simulator kernel'
    project = (ROOT / 'ios/project.yml').read_text()
    (folder / 'ios/project.development.yml').write_text(project)
    project = re.sub(r'packages:\n.*?(?=targets:)', '', project, flags=re.S)
    project = project.replace('      - package: FlutterNativeIntegration',
        '      - framework: Frameworks/Flutter.xcframework\n        embed: true\n      - framework: Frameworks/App.xcframework\n        embed: true')
    project = re.sub(r'^        FLUTTER_.*\n', '', project, flags=re.M)
    project = re.sub(r'    postBuildScripts:\n.*?(?=  TenoTests:)', '', project, flags=re.S)
    project = re.sub(r'      preActions:\n.*?(?=    run:)', '', project, flags=re.S)
    project = project.replace('    run:\n      config: Debug', '    run:\n      config: Release')
    (folder / 'ios/project.yml').write_text(project)
    subprocess.run(['xcodegen', 'generate', '--spec', str(folder / 'ios/project.yml')], check=True)
    compatibility = compatible_project(folder / 'ios/Teno.xcodeproj/project.pbxproj')
    (folder / 'ios/Verify-Xcode.command').chmod(0o755)
    readme = (ROOT / 'ios/INSTALL.txt').read_text(encoding='utf-8')
    assert f'iOS {version} / Build{build}' in readme, 'Update the recipient guide with the build identity'
    (folder / '开始使用.txt').write_text(readme, encoding='utf-8')
    ui_version = re.search(r'^version:\s*([^+\s]+)', (ROOT/'shared-ui/pubspec.yaml').read_text(), re.M)[1]
    metadata = {'version':version,'version_code':int(build),'bundle_id':bundle_id,'app_ui_base':ui_version,'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'flutter':'3.47.9','signing':'recipient','framework_mode':'Release device + Debug simulator','xcode_only':True,
        'hardware_acceptance':'pending: physical iPhone and JWD',
        'xcode_compatibility_target':'14.3.1','project_compatibility':compatibility,
        'recipient_verification':'ios/Verify-Xcode.command'}
    (folder / 'manifest.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
    return folder


def archive(folder: Path) -> Path:
    lines = []
    for file in sorted(folder.rglob('*')):
        if file.is_file() and file.name != 'SHA256SUMS.txt' and 'xcuserdata' not in file.parts:
            lines.append(hashlib.sha256(file.read_bytes()).hexdigest() + '  ' + file.relative_to(folder).as_posix())
    (folder / 'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n')
    target = folder.with_name(folder.name + '.zip')
    with zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
        for file in sorted(folder.rglob('*')):
            if file.is_file() and 'xcuserdata' not in file.parts:
                bundle.write(file,file.relative_to(folder.parent).as_posix())
    return target


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--frameworks',type=Path)
    parser.add_argument('--output',type=Path,default=ROOT/'ios/build/handoff')
    parser.add_argument('--archive',type=Path)
    args = parser.parse_args()
    print(archive(args.archive) if args.archive else prepare(args.frameworks.resolve(),args.output.resolve()))
