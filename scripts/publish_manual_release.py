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

VERSION = '0.9.4'
CODE = 25
NOTES = ROOT / 'RELEASE-0.9.4.txt'
MANIFEST = ROOT / 'dist/Teno-0.9.4-manifest.json'
APK = ROOT / 'dist/Teno-0.9.4.apk'
SCREEN = ROOT / 'verification/v0.9.4/templates-zh-360.png'
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
        {'label': 'Android 0.9.4 manifest', 'reference': rel(MANIFEST), 'sha256': sha(MANIFEST)},
        {'label': 'Android 0.9.4 / iOS 1.0 release notes', 'reference': rel(NOTES), 'sha256': sha(NOTES)},
    ]


def android():
    now = datetime.now(timezone(timedelta(hours=8))).isoformat()
    report = {
        'platform': 'android', 'version': VERSION,
        'build_number': 'manual-0.9.4-' + sha(MANIFEST)[:12] + '-android',
        'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        'occurred_at': now, 'outcome': 'passed', 'implementation': 'implemented',
        'physical': 'pending', 'distribution': 'internal',
        'title': words('Android 0.9.4：模板选择对齐 PLAUD', 'Android 0.9.4: PLAUD-aligned template picker'),
        'changes': [
            words('模板选择改为全屏：搜索、最近使用/收藏横排、全部模板；卡片含来源徽标与“上次使用”，页内选中后底部固定应用。',
                  'Full-screen template picker with search, Recently used and Favorites shelves, source badges, Last used, in-page selection and a fixed apply button.'),
            words('永久删除同时清理手机本地副本；回收站支持恢复/永久删除操作表、左滑删除与一键清空。',
                  'Permanent delete removes local copies; trash supports restore/delete, swipe and empty-all.'),
            words('中文页面剩余英文清理：上传/解码百分比、组合设备状态、来源/使用/返回按钮和登录标语。',
                  'Remaining English removed from Chinese pages: upload/decode percentages, compound device status, citation/use/return buttons and the login tagline.'),
            words('模板名称、分类与章节按中英文显示；内置模板指令按输出语言选择。',
                  'Template names, categories and sections are bilingual; built-in instructions follow the output language.'),
        ],
        'modules': [
            {'key': 'summary', 'scope': words('模板选择页、最近/收藏、来源徽标与输出语言', 'Template picker, recent/favorites, source badges and output language'),
             'implementation': 'implemented', 'verification': 'passed', 'pending': words('真实手机逐页视觉验收', 'Physical page-by-page visual acceptance')},
            {'key': 'library', 'scope': words('回收站恢复/永久删除、本地副本清理、一键清空', 'Trash restore/permanent delete, local copy cleanup and empty-all'),
             'implementation': 'implemented', 'verification': 'passed', 'pending': words('真实手机删除与空间释放验收', 'Physical delete and storage-release acceptance')},
            {'key': 'distribution', 'scope': words('原签名 0.9.4 包，正式基线不变', 'Original-signer 0.9.4 package; formal baseline unchanged'),
             'implementation': 'implemented', 'verification': 'passed', 'pending': words('Magic4 Pro / JWD 实机验收', 'Magic4 Pro / JWD physical acceptance')},
        ],
        'tests': [
            {'name': words('Flutter 全量自动测试', 'Complete Flutter tests'), 'status': 'passed',
             'count': 458, 'environment': 'unit', 'source': rel(NOTES)},
            {'name': words('模板选择矩阵（中英 × 360/1100）', 'Template picker matrix (en/zh x 360/1100)'),
             'status': 'passed', 'count': 4, 'environment': 'unit', 'source': rel(NOTES)},
        ],
        'sources': sources(),
        'pending': [words('Magic4 Pro、真实 JWD、iPhone 原 Team 签名安装、Safari 仍待实机。',
                          'Magic4 Pro, real JWD, signed iPhone installation and Safari remain pending.')],
        'installation': words('用此原签名 APK 覆盖安装 0.9.3 或更早版本；不要先卸载。保留账号、本机录音、设备码与上传队列。',
                              'Install this original-signer APK over 0.9.3 or earlier without uninstalling. Accounts, local recordings, device codes and upload queues are preserved.'),
        'dependency': words('共享后端 1.8.0；无迁移、无生成 Prompt 变更，本轮未调用模型。',
                            'Shared backend 1.8.0; no migration or prompt change and no model calls in this round.'),
        'assets': [],
    }
    files = [evidence(APK, 'apk', 'Android 0.9.4 原签名包', 'Android 0.9.4 original-signer APK'),
             evidence(NOTES, 'evidence', '0.9.4 发布说明', '0.9.4 release notes')]
    if SCREEN.exists():
        files.append(evidence(SCREEN, 'screenshot', '模板选择页（中文 360dp）', 'Template picker (Chinese, 360dp)'))
    return {'report': report, 'files': files}


def ios(include_ipa=True):
    now = datetime.now(timezone(timedelta(hours=8))).isoformat()
    report = {
        'platform': 'ios', 'version': '1.0.0',
        'build_number': 'manual-1.0-build17-' + sha(IOS_SOURCE)[:12] + '-ios',
        'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT.parent / 'android-ios1431', text=True).strip(),
        'occurred_at': now, 'outcome': 'passed', 'implementation': 'implemented',
        'physical': 'pending', 'distribution': 'unsigned',
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
            {'label': 'Release notes', 'reference': rel(NOTES), 'sha256': sha(NOTES)},
            {'label': 'Xcode signing handoff', 'reference': rel(MANIFEST), 'sha256': sha(MANIFEST)},
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
    parser.add_argument('--output', type=Path, default=Path.home() / '.teno/development-releases/manual')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    envelopes = [android()]
    if not args.skip_ios and IOS_SOURCE.exists():
        envelopes.append(ios())
    for envelope in envelopes:
        (args.output / f"{envelope['report']['platform']}.json").write_text(
            json.dumps(envelope, ensure_ascii=False, indent=2), encoding='utf-8')
    if args.prepare_only:
        print('Prepared', len(envelopes), 'envelopes in', args.output)
        return

    config = configuration(args.credential)
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


if __name__ == '__main__':
    main()
