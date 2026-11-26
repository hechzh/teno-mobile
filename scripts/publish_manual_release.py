#!/usr/bin/env python3
"""Publish reviewed hand-built Android/iOS outputs to the development page.

Manual builds are not reported by CI, so this script normalizes the local
manifests into the same private report envelope used by the mobile workflow.
It never calls a model or changes the application baseline.
"""
import argparse
import json
import shutil
import subprocess
from datetime import datetime, timezone, timedelta
from pathlib import Path

from report_development import ROOT, words, sha, configuration, send
from showcase import prepare as prepare_showcase, publish as publish_showcase

VERSION = '0.9.7'
CODE = 29
NOTES = ROOT / f'RELEASE-{VERSION}.txt'
IOS_NOTES = ROOT / 'RELEASE-0.9.4.txt'
MANIFEST = ROOT / f'dist/Teno-{VERSION}-manifest.json'
APK = ROOT / f'dist/Teno-{VERSION}.apk'
SCREEN = ROOT / f'verification/v{VERSION}/build{CODE}/note-tabs-zh.png'
IOS_DIST = ROOT.parent / 'android-ios1431/dist'
IOS_IPA = IOS_DIST / 'Teno-iOS-1.0-build17-unsigned.ipa'
IOS_SOURCE = IOS_DIST / 'Teno-iOS-1.0-build17-Xcode.zip'
IOS_SCREEN = IOS_DIST / '01-login-build17.png'
IOS_INSTALL = ROOT.parent / 'android-ios1431/ios/INSTALL.txt'
CI_RUN = 'https://github.com/hechzh/teno-mobile/actions/runs/45182617382'


def rel(path):
    return Path(path).relative_to(ROOT).as_posix()


def evidence(path, kind, zh, en):
    return {'path': str(Path(path).resolve()), 'kind': kind,
            'sha256': sha(path), 'label': words(zh, en)}


def sources():
    return [
        {'label': f'Android {VERSION} manifest', 'reference': rel(MANIFEST), 'sha256': sha(MANIFEST)},
        {'label': f'Android {VERSION} release notes', 'reference': rel(NOTES), 'sha256': sha(NOTES)},
    ]


def android():
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    expected = (VERSION, CODE, APK.name, sha(APK), APK.stat().st_size)
    actual = tuple(manifest.get(field) for field in ('version', 'version_code', 'apk', 'sha256', 'bytes'))
    if expected != actual:
        raise ValueError('Manifest does not match the selected Android package')
    report = {
        'platform': 'android', 'version': VERSION,
        'build_number': f'manual-{VERSION}-build{CODE}-' + sha(MANIFEST)[:12] + '-android',
        'commit': manifest['source_commit'], 'occurred_at': manifest['packaged_at'],
        'outcome': 'passed', 'implementation': 'implemented',
        'physical': 'pending', 'distribution': 'internal',
        'title': words(f'Android {VERSION} / {CODE} 个人工作空间与录音笔记',
                       f'Android {VERSION} / {CODE} personal workspaces and recording notes'),
        'changes': manifest['changes'],
        'modules': [
            {'key': 'summary', 'scope': words('首篇直达模板选择，其他笔记可换模板或移到回收站', 'Open the template picker from the first note and manage the template or Trash for other notes'),
             'implementation': 'implemented', 'verification': 'passed', 'pending': words('真实手机交互验收', 'Physical handset interaction')},
            {'key': 'library', 'scope': words('个人工作空间切换、搜索、移动和上传目标', 'Personal workspace switching, search, moves, and upload destination'),
             'implementation': 'implemented', 'verification': 'passed', 'pending': words('真实手机录后验收', 'Post-recording acceptance on a physical phone')},
            {'key': 'distribution', 'scope': words('APK 包名、版本和原签名', 'APK identity, version and original signer'),
             'implementation': 'implemented', 'verification': 'passed', 'pending': words('真实手机覆盖安装', 'Physical in-place upgrade')},
        ],
        'tests': manifest['tests'],
        'sources': sources(),
        'pending': [words('真机录音上传、JWD 同步和原签名覆盖安装待复核。',
                          'Physical recording upload, JWD sync, and updating on a handset await verification.')],
        'installation': words('直接覆盖安装当前 Teno；保留本机录音和账号。', 'Install over the existing Teno app to keep local recordings and the account.'),
        'dependency': words('依赖共享后端的工作空间与录音笔记更新（迁移 014）。', 'Requires the shared backend workspace and recording note update (migration 014).'),
        'assets': [],
    }
    files = [{**evidence(APK, 'apk', f'Android {VERSION} / {CODE} 原签名包', f'Android {VERSION} / {CODE} original-signer APK'),
              'filename': f'Teno-{VERSION}-build{CODE}.apk'},
             evidence(NOTES, 'evidence', '发布说明', 'Release notes'),
             {**evidence(MANIFEST, 'evidence', '构建清单（JSON 文本）', 'Build manifest (JSON text)'),
              'filename': f'Teno-{VERSION}-build{CODE}-manifest.txt'},
             evidence(SCREEN.parent / 'workspace-home-zh.png', 'screenshot', '个人工作空间首页', 'Personal workspace home'),
             evidence(SCREEN.parent / 'workspace-switch-zh.png', 'screenshot', '切换个人工作空间', 'Switch personal workspaces'),
             evidence(SCREEN, 'screenshot', '录音笔记标签页', 'Notes for a recording'),
             evidence(SCREEN.parent / 'primary-template-picker-zh.png', 'screenshot', '首篇笔记模板选择', 'Primary note template picker'),
             evidence(SCREEN.parent / 'note-actions-zh.png', 'screenshot', '所选笔记的操作菜单', 'Selected note actions'),
             evidence(SCREEN.parent / 'delete-note-zh.png', 'screenshot', '将所选笔记移到回收站', 'Move selected note to Trash'),
             evidence(SCREEN.parent / 'change-template-zh.png', 'screenshot', '替换所选笔记的摘要模板', 'Change the selected note template')]
    return {'report': report, 'files': files}


def ios(include_ipa=False):
    now = datetime.now(timezone(timedelta(hours=8))).isoformat()
    report = {
        'platform': 'ios', 'version': '1.0.0',
        'build_number': 'manual-1.0-build17-' + sha(IOS_SOURCE)[:12] + '-ios',
        'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT.parent / 'android-ios1431', text=True).strip(),
        'occurred_at': now, 'outcome': 'passed', 'implementation': 'implemented',
        'physical': 'pending', 'distribution': 'evidence',
        'title': words('iOS 1.0 / build17：模板选择对齐 PLAUD', 'iOS 1.0 build17: PLAUD-aligned template picker'),
        'changes': [
            words('模板选择页与 Android 0.9.4 一致：搜索、最近/收藏、来源徽标、页内选择与固定应用。',
                  'Template picker matches Android 0.9.4: search, recent/favorites, source badges, in-page selection and a fixed apply button.'),
            words('回收站永久删除清理本地副本；中文页面剩余英文清理。',
                  'Trash permanent delete removes local copies; remaining English removed from Chinese pages.'),
        ],
        'modules': [
            {'key': 'summary', 'scope': words('模板选择、生成语言与最近/收藏', 'Template selection, output language and recent/favorites'),
             'implementation': 'implemented', 'verification': 'passed', 'pending': words('真实 iPhone 视觉验收', 'Physical iPhone visual acceptance')},
            {'key': 'library', 'scope': words('回收站与本地副本删除', 'Trash and local copy deletion'),
             'implementation': 'implemented', 'verification': 'partial', 'pending': words('真实 iPhone 删除验收', 'Physical iPhone deletion acceptance')},
            {'key': 'distribution', 'scope': words('未签名 ARM64 IPA 与可重签 Xcode 工程', 'Unsigned ARM64 IPA and re-signable Xcode project'),
             'implementation': 'implemented', 'verification': 'partial', 'pending': words('原 Team 签名、覆盖安装与 AltStore 验收', 'Original Team signing, upgrade and AltStore acceptance')},
        ],
        'tests': [
            {'name': words('iOS 原生 XCTest', 'iOS native XCTest'), 'status': 'passed',
             'count': 19, 'environment': 'simulator', 'source': CI_RUN},
            {'name': words('模拟器启动与登录页', 'Simulator launch and login screen'), 'status': 'passed',
             'environment': 'simulator', 'source': CI_RUN},
        ],
        'sources': [
            {'label': 'iOS GitHub Actions run', 'reference': CI_RUN},
            {'label': 'Release notes', 'reference': rel(IOS_NOTES), 'sha256': sha(IOS_NOTES)},
            {'label': 'Xcode signing handoff', 'reference': 'ios/INSTALL.txt', 'sha256': sha(IOS_INSTALL)},
        ],
        'pending': [words('真实 iPhone 的原 Team 签名安装、覆盖升级、麦克风/蓝牙后台与 JWD 联调仍待实机。',
                          'Physical iPhone signing, upgrade, microphone/Bluetooth background and JWD validation remain pending.')],
        'installation': words('未签名 ARM64 IPA，需用原 Team 或 AltStore 重签后安装；不要先卸载，保持 com.jwd.ZhiYan 覆盖更新。',
                              'Unsigned ARM64 IPA: re-sign with the original Team or AltStore. Do not uninstall; update over com.jwd.ZhiYan.'),
        'dependency': words('共享后端 1.8.0；CI 使用 Xcode 27.2 / iOS 27.2 SDK。',
                            'Shared backend 1.8.0; CI used Xcode 27.2 / iOS 27.2 SDK.'),
        'assets': [],
    }
    files = [evidence(IOS_SOURCE, 'source', 'iOS 1.0 build17 Xcode 工程', 'iOS 1.0 build17 Xcode project')]
    if include_ipa:
        files.insert(0, evidence(IOS_IPA, 'ipa', 'iOS 未签名 ARM64 IPA', 'Unsigned iOS ARM64 IPA'))
    if IOS_INSTALL.exists():
        files.append(evidence(IOS_INSTALL, 'evidence', 'iPhone 安装步骤', 'iPhone installation guide'))
    if IOS_SCREEN.exists():
        files.append(evidence(IOS_SCREEN, 'screenshot', 'iOS 模拟器登录页', 'iOS simulator login screen'))
    return {'report': report, 'files': files}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--credential', type=Path, default=Path.home() / '.ssh/teno-development-local.json')
    parser.add_argument('--prepare-only', action='store_true')
    parser.add_argument('--skip-ios', action='store_true')
    parser.add_argument('--no-showcase', action='store_true')
    parser.add_argument('--showcase-gallery', type=Path, default=ROOT / f'design-baseline/v{VERSION}/build{CODE}')
    parser.add_argument('--showcase-only', action='store_true')
    parser.add_argument('--build-id')
    parser.add_argument('--output', type=Path, default=Path.home() / '.teno/development-releases/manual')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    envelopes = [android()]
    if not args.skip_ios and IOS_SOURCE.exists():
        envelopes.append(ios())
    for envelope in envelopes:
        (args.output / f"{envelope['report']['platform']}.json").write_text(
            json.dumps(envelope, ensure_ascii=False, indent=2), encoding='utf-8')
    if not args.no_showcase:
        android_report = envelopes[0]['report']
        root, gallery_version, stale, pages, acceptance_value = prepare_showcase(
            android_report['version'], android_report['commit'],
            str(args.showcase_gallery) if args.showcase_gallery else None,
        )
        (args.output / 'showcase-preview.json').write_text(json.dumps({
            'gallery': str(root),
            'gallery_version': gallery_version,
            'stale': stale,
            'pages': len(pages),
            'screenshots': sum(len(page['variants']) for page in pages),
            'acceptance': acceptance_value,
        }, ensure_ascii=False, indent=2), encoding='utf-8')
        print('Showcase prepared:', len(pages), 'pages,',
              sum(len(page['variants']) for page in pages), 'screenshots',
              '(stale gallery)' if stale else '(version-specific gallery)')
    if args.prepare_only:
        print('Prepared', len(envelopes), 'envelopes in', args.output)
        return

    config = configuration(args.credential)
    if args.showcase_only:
        if not args.build_id:
            raise SystemExit('--showcase-only requires --build-id')
        if args.no_showcase:
            raise SystemExit('--showcase-only conflicts with --no-showcase')
        report = android()['report']
        publish_showcase(args.build_id, report['version'], report['commit'], config,
                         args.output, str(args.showcase_gallery) if args.showcase_gallery else None)
        return
    for envelope in envelopes:
        platform = envelope['report']['platform']
        try:
            result = send(envelope, config, Path.home() / '.teno/development-outbox')
        except ValueError:
            if platform != 'ios':
                raise
            # The development API verifies the IPA bundle identifier against the
            # Android package; keep the Xcode handoff and evidence if it refuses.
            print('IPA asset rejected; publishing the Xcode handoff instead')
            result = send(ios(include_ipa=False), config, Path.home() / '.teno/development-outbox')
        print(platform, 'published:', result.get('id'), '(duplicate)' if result.get('duplicate') else '')
        if platform == 'android' and not args.no_showcase:
            report = envelope['report']
            publish_showcase(
                result['id'], report['version'], report['commit'], config,
                args.output, str(args.showcase_gallery) if args.showcase_gallery else None,
            )


if __name__ == '__main__':
    main()
