"""Create a relocatable, Xcode-only signing handoff from CI-built XCFrameworks."""
import argparse
import hashlib
import json
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def prepare(frameworks: Path, output: Path) -> Path:
    version = re.search(r'versionName\s+[\'"]([^\'"]+)', (ROOT / 'app/build.gradle').read_text())[1]
    folder = output / f'Teno-iOS-{version}-Xcode'
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
    readme = f'''Teno iOS {version} / 15 · Xcode 签名源码包

使用 macOS 与 Xcode 16.4 或更新兼容版本，部署目标 iOS 15。
1. 解压整个目录，直接打开 ios/Teno.xcodeproj，选择 Teno scheme。
2. 在 Teno target 的 Signing & Capabilities 中选择自己的 Team。现有包名 com.teno.app；
   如果签名方没有该标识的权限，请使用自己拥有的标识，并在 Apple 后台创建对应 App。
3. 选择 iPhone 真机或 Any iOS Device，Product > Archive，再由签名方上传。
4. 首次安装允许蓝牙/麦克风等实际使用的权限。真实 iPhone/JWD 测试仍需验收。

Frameworks 已包含当前 shared-ui 的 Release App 与 Flutter 引擎、设备及模拟器切片；
打开、编译、签名此交付包不需要安装 Flutter、CocoaPods 或 XcodeGen，也不需要 CI 路径。
原生 Swift/Objective-C 源码可直接编辑。修改 Dart UI 后需要 Flutter 3.47.9 重新生成
App.xcframework，并同时使用配套 Flutter.xcframework；shared-ui/ 为完整共享 UI 源码。
ios/project.development.yml 保留 Flutter 开发集成规格；它不用于本包的直接签名编译。

包含中英文、新版资料库/导入/转写与 Notes/模板/Ask/分享、iOS 系统录音与 JWD 自动连接。
首次连接自动核验信号最强的候选，生成并保存设备码后授权；重连使用上次成功的设备。
不显示蓝牙选择列表；不会重置设备或绕过已有绑定，拒绝时需要恢复原设备码。
账号、处理接口与现有后端共用。后台传输由 iOS 调度，处理状态在前台定期更新。
不包含 Apple 账号、证书、描述文件、私钥或真实用户数据；本包尚未签名或上传商店。
'''
    (folder / '开始使用.txt').write_text(readme, encoding='utf-8')
    metadata = {'version':version,'version_code':15,'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'flutter':'3.47.9','signing':'recipient','framework_mode':'Release','xcode_only':True,
        'hardware_acceptance':'pending: physical iPhone and JWD'}
    (folder / 'manifest.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
    return folder


def archive(folder: Path) -> Path:
    lines = []
    for file in sorted(folder.rglob('*')):
        if file.is_file() and file.name != 'SHA256SUMS.txt' and 'xcuserdata' not in file.parts:
            lines.append(hashlib.sha256(file.read_bytes()).hexdigest() + '  ' + file.relative_to(folder).as_posix())
    (folder / 'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n')
    target = folder.with_suffix('.zip')
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
