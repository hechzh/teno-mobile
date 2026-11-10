#!/usr/bin/env python3
"""Normalize reviewed release manifests; never call a language model.

The initial catalog is grounded in RELEASE-0.4.4/0.5.0 and their verification
reports. Other versions retain their manifest facts without inheriting scope or
tests from an older release. Baseline promotion is always an explicit option.
"""
import argparse
import json
import os
import subprocess
from pathlib import Path
from report_development import ROOT, words, sha, configuration, send

CERT = '56291d8fefaf737b522f88b075960ecddfe8f2d1e6794d538d4f46ad2b1d1291'


def normalize(manifest_path, output, baseline=False):
    manifest_path = Path(manifest_path).resolve(); manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    version = manifest['version']; output=Path(output); output.mkdir(parents=True,exist_ok=True)
    release=ROOT/f'RELEASE-{version}.txt'; qa=ROOT/'verification'/('v'+version)
    assert manifest['package']=='com.teno.app' and manifest['signer_sha256']==CERT
    assert manifest['apk_signature_v2_verified'] and not manifest['debuggable']
    apk=manifest_path.parent/manifest['apk']; assert sha(apk)==manifest['sha256'] and apk.stat().st_size==manifest['bytes']
    commit=manifest.get('source_commit')
    if not commit and version=='0.4.4': commit=subprocess.check_output(['git','rev-parse','android-v0.4.4^{commit}'],cwd=ROOT,text=True).strip()
    if commit: assert subprocess.check_output(['git','cat-file','-t',commit],cwd=ROOT,text=True).strip()=='commit'
    source_time=manifest.get('packaged_at') or manifest['built_at_beijing']
    catalog = [
      ('recording','录音卡主入口、手机录音、暂停恢复与本机保存','Recorder-first capture, phone recording, pause/resume and local saving','真实 JWD 暂停恢复、断连及长录音验收','Validate real JWD pause/resume, disconnection and long recordings'),
      ('sync','音频导入、完整文件校验、持久上传与失败重试','Audio import, file integrity, persistent uploads and retry','真实设备断网恢复、后台上传与完整传输验收','Validate device reconnection, background uploads and complete transfers'),
      ('library','文件夹、搜索、播放、倍速与回收站','Folders, search, playback, speed controls and trash','真实手机的播放、系统导入与分享验收','Validate playback, system import and sharing on physical phones'),
      ('summary','Automatic 转写、摘要编辑、模板与版本','Automatic transcription, summary editing, templates and versions','真实录音的语言识别与结果质量待验收','Validate language detection and output quality with real recordings'),
      ('ask','基于录音资料提问、引用与对话历史','Recording-grounded questions, citations and conversation history','真实手机上的提问与来源跳转验收','Validate questions and source navigation on physical phones'),
      ('distribution','原签名覆盖更新，保留账号、密钥与本机文件','Same-signer update retaining accounts, device keys and local files','Magic4 Pro、iPhone 与 AltStore 安装验收','Validate Magic4 Pro, iPhone and AltStore installation'),
    ]
    if version=='0.6.0':
        catalog=[
          ('recording','录音、照片、高亮、完整本机保留与默认云处理','Recording, photos, highlights, local originals and default cloud processing','Magic4 Pro / JWD 长录音与后台验收','Validate Magic4 Pro / JWD long recordings and background behavior'),
          ('library','音视频、文档与图片导入，文件夹、批量管理和搜索定位','Media, document and image imports; folders, batch management and search navigation','实机系统分享、照片、日历与文件权限验收','Validate system sharing, photos, calendar and file permissions on physical phones'),
          ('summary','转写清理、说话人命名、多笔记、模板与来源','Transcript cleanup, speaker naming, multiple notes, templates and sources','真实客户录音质量与接近120分钟供应商实测待验收','Customer-audio quality and near-120-minute provider acceptance remain pending'),
          ('ask','录音、笔记、文档和文件夹问答，语音问题预览与引用','Recording, note, document and folder Chat; editable voice questions and citations','真实手机语音问题、引用定位和保存回答验收','Validate voice questions, citations and saved answers on physical phones'),
          ('sync','音频和文档导出、7天默认分享链接、撤销、主题与应用锁','Audio/document exports, seven-day default share links, revocation, themes and App lock','实机生物识别/锁屏、导出阅读器与分享行为验收','Validate device authentication, export readers and sharing on physical phones'),
          ('distribution','Android0.6.0原签名覆盖更新；共享后端1.4.0兼容扩展','Same-signer Android0.6.0 update and compatible backend1.4.0 extension','保留0.5.0已确认交付基线，真实手机验收待完成','Keep the confirmed0.5.0 baseline; physical phone acceptance remains pending'),
        ]
    if version=='0.6.1':
        catalog=[
          ('library','PLAUD 4.x 页面结构、可展开文件夹、真实统计、组合筛选与分页','PLAUD 4.x page structure, expandable folders, complete counts, combined filters and pagination','缺图状态按共用控件延伸，实机待验收','Missing reference states use shared controls; physical acceptance pending'),
          ('recording','录音底部弹层、转写播放和段落菜单；原录音与队列保留','Recording sheets, transcript playback and paragraph menus; original recording and queues retained','Magic4 Pro / JWD 待验收','Magic4 Pro / JWD acceptance pending'),
          ('summary','模板分类与 My templates、笔记切换、日历分组','Template categories and My templates, note switching and calendar groups','真实手机日历权限待验收','Physical calendar permissions pending'),
          ('sync','导入、固定版本分享与内容子面板、分类导出和分组设置','Import sheets, fixed-version sharing with content selection, categorized exports and grouped settings','手机导入导出和应用锁待验收','Physical import/export and App lock pending'),
          ('distribution','Android 0.6.1 原签名覆盖更新；后端 1.4.1 兼容查询扩展','Same-signer Android 0.6.1 update; compatible backend 1.4.1 queries','不提升已确认基线；本轮不交付 iOS','Confirmed baseline unchanged; no iOS delivery'),
        ]
    modules=[{'key':key,'scope':words(zh,en),'implementation':'implemented','verification':'partial','pending':words(pzh,pen)} for key,zh,en,pzh,pen in catalog] if version in ('0.4.4','0.5.0','0.6.0','0.6.1') else []
    if version=='0.4.4':
        modules[-1]['pending']=words('Magic4 Pro 原签名覆盖更新与权限验收','Validate same-signer update and permissions on Magic4 Pro')
    changes = [words('录音与导入统一 Automatic，摘要语言独立配置。','Recording and import use Automatic recognition; summary language is configured independently.')]
    if version=='0.5.0':
        changes=[words('Flutter 共享页面与 Android / iOS 原生宿主接入，保持原账号、密钥、录音和上传队列。','Flutter UI integrated with Android and iOS native hosts, preserving accounts, keys, recordings and upload queues.'),words('保留录音、资料库、转写摘要、Ask、设置与分享；团队协作继续在网页使用。','Recording, library, summaries, Ask, settings and sharing remain in the App; team collaboration remains on the web.')]
    if version=='0.6.0':
        changes=[words('按PLAUD4.x官方资料对齐Android个人核心；独立逐页截图与差异清单。','Android personal core aligned to official PLAUD4.x references, with independent page captures and differences.'),
            words('默认云处理保留显式关闭；补全文档/OCR、多笔记、说话人、Ask、日历、导出与可撤销分享。','Default cloud processing preserves opt-outs; adds files/OCR, multiple notes, speakers, Ask, calendar, exports and revocable sharing.')]
    if version=='0.6.1':
        changes=[words('按已有功能对齐页面结构、入口、菜单层级及弹层；修正参考图映射，逐状态记录缺图推定和保留差异。','Align existing page structure, entries, menu hierarchy and sheets; correct reference mapping and record inferred states and retained differences.'),words('新增能力声明、账号隔离的组合搜索筛选与完整统计；不改变生成 Prompt、录音及上传队列。','Add capabilities, owner-scoped combined search filters and complete counts; generation prompts, recordings and upload queues are preserved.')]
    sources=[{'label':f'Teno {version} release manifest','reference':f'dist/{manifest_path.name}','sha256':sha(manifest_path)}]
    if release.exists(): sources.append({'label':f'Teno {version} release notes','reference':release.name,'sha256':sha(release)})
    tests=[]; summaries=[]
    def evidence(path, namezh, nameen, environment, count=None):
        doc=json.loads(path.read_text(encoding='utf-8')); assert doc.get('all_passed') is True
        checks=doc.get('checks',[])
        if checks: assert all(c.get('passed') for c in checks)
        if count is not None and checks: assert len(checks)==count
        ref=path.relative_to(ROOT).as_posix()
        sources.append({'label':nameen,'reference':ref,'sha256':sha(path)})
        tests.append({'name':words(namezh,nameen),'status':'passed','environment':environment,'count':count,'source':ref})
        summaries.append({'source':ref,'sha256':sha(path),'status':'passed','count':count,'environment':environment,
                          'checks':[{'name':c['name'],'passed':c['passed']} for c in checks]})
        return doc
    if version=='0.4.4':
        summary=evidence(qa/'automatic-summary.json','Automatic 界面与大字号检查','Automatic UI and large-text checks','emulator',manifest['ui_checks_passed'])
        assert sum(c['checks_passed'] for c in summary['configurations'])==manifest['ui_checks_passed']
        installed=evidence(qa/'release-install-report.json','覆盖安装与冷启动','Upgrade installation and cold launch','emulator')
        assert installed['apk_sha256']==manifest['sha256'] and not installed['uninstalled']
    elif version=='0.5.0':
        evidence(qa/'full-runtime-report.json','从 0.4.4 覆盖升级保留检查','Upgrade retention from 0.4.4','emulator',manifest['upgrade_runtime_checks'])
        evidence(qa/'regression-runtime-report.json','原生录音、上传与隔离回归','Native recording, upload and isolation regression','emulator',manifest['regression_runtime_checks'])
        installed=evidence(qa/'final-install-report.json','签名包覆盖安装与冷启动','Signed release installation and cold launch','emulator')
        assert installed['apk_sha256']==manifest['sha256'] and not installed['uninstalled']
        for key,zh,en in [('flutter_tests','Flutter 自动测试','Flutter automated tests'),('jwd_protocol_checks','JWD 协议测试（合成数据）','JWD protocol tests (synthetic data)')]:
            tests.append({'name':words(zh,en),'status':'passed','environment':'unit','count':manifest[key],'source':release.name})
    elif version=='0.6.0':
        evidence(qa/'full-runtime-report.json','0.5.0至0.6.0候选包覆盖保留检查','0.5.0 to0.6.0 candidate upgrade retention','emulator',manifest['upgrade_runtime_checks'])
        evidence(qa/'regression-runtime-report.json','最终Android录音、导入、系统选择器与账号隔离','Final Android recording, imports, system pickers and account isolation','emulator',manifest['regression_runtime_checks'])
        installed=evidence(qa/'final-install-report.json','最终原签名包安装与冷启动','Final signed APK installation and cold launch','emulator')
        assert installed['apk_sha256']==manifest['sha256'] and not installed['uninstalled']
        evidence(qa/'backend-acceptance.json','后端迁移、旧端兼容及真实供应商验收','Backend migration, legacy compatibility and real-provider acceptance','server')
        tests.append({'name':words('本轮Flutter页面与交互回归','Current Flutter page and interaction regression'),'status':'passed','environment':'unit','count':manifest['flutter_tests'],'source':release.name})
    elif version=='0.6.1':
        evidence(qa/'full-runtime-report.json','0.6.0 至 0.6.1 覆盖保留检查','0.6.0 to 0.6.1 upgrade retention','emulator',manifest['upgrade_runtime_checks'])
        evidence(qa/'regression-runtime-report.json','最终 APK 原生回归与系统界面','Final APK native regression and system surfaces','emulator',manifest['regression_runtime_checks'])
        installed=evidence(qa/'final-install-report.json','原签名包安装与冷启动','Signed APK installation and cold launch','emulator')
        assert installed['apk_sha256']==manifest['sha256'] and not installed['uninstalled']
        evidence(qa/'backend-acceptance.json','查询增量、隔离回归与旧端兼容','Read-query additions, isolated regression and legacy compatibility','server')
        tests.append({'name':words('Flutter 页面及交互回归','Flutter page and interaction regression'),'status':'passed','environment':'unit','count':manifest['flutter_tests'],'source':release.name})
    tests.append({'name':words(f"Lint：0 错误 / {manifest['lint_warnings']} 警告",f"Lint: 0 errors / {manifest['lint_warnings']} warnings"),'status':'passed','environment':'static','source':f'dist/{manifest_path.name}'})
    report={'platform':'android','version':version,'commit':commit,'build_number':f"release-{version}-{sha(manifest_path)[:12]}-android",
            'occurred_at':source_time,'outcome':'passed','implementation':'implemented' if modules else 'unknown','physical':'pending','distribution':'internal',
            'promote_baseline':baseline,'title':words('Automatic 录音与导入' if version=='0.4.4' else 'Teno 双平台首版内测','Automatic recording and import' if version=='0.4.4' else 'Teno cross-platform internal release'),
            'changes':changes,'modules':modules,'tests':tests,'sources':sources,'assets':[],
            'pending':[words('Magic4 Pro 的权限、锁屏、长录音与省电策略；真实 JWD BLE、固件和文件完整传输待验收。','Magic4 Pro permissions, lock screen, long recordings and power management; real JWD BLE, firmware and complete file transfers remain pending.')],
            'installation':words('用此原签名 APK 覆盖安装已有 Teno；不要先卸载或清除数据。保留原设备密钥和账号。CI debug APK 不能作为覆盖更新包。Android 8.0 及以上，真实 Magic4 Pro 仍待验收。','Install this original-signer APK over the existing Teno installation. Do not uninstall or clear data. Retain the device key and account. Do not use CI debug APKs as an update. Android 8.0 or later; Magic4 Pro acceptance remains pending.'),
            'dependency':words('复用现有账号、Azure 转写、DeepSeek 摘要与 Ask 接口。此处展示历史验证，不重新调用模型。','Uses existing accounts, Azure transcription, DeepSeek summaries and Ask APIs. This page displays historical evidence without invoking models.')}
    if version=='0.4.4':
        report['installation']=words('历史内测包，仅供版本回溯。当时用于从 0.4.3 覆盖升级至 0.4.4；若已安装 0.5.0 或更高版本，不要用旧包降级，也不要卸载当前 App。原签名、账号、设备密钥和本机文件须保留。', 'Historical internal package for traceability. Originally used to upgrade 0.4.3 to 0.4.4. If 0.5.0 or newer is already installed, do not downgrade or uninstall the current App. Preserve the original signer, account, device key and local files.')
    if version=='0.6.0':
        report['title']=words('Android个人核心与UI对齐','Android personal core and UI alignment')
        report['dependency']=words('共享后端1.4.0／迁移007；复用Azure和DeepSeek。真实合成验收与用量单独记录，团队网页流程保留。','Backend1.4.0 / migration007; uses Azure and DeepSeek. Synthetic real-provider acceptance and usage are recorded separately; team web workflows are retained.')
        report['pending'].append(words('本轮不构建iOS；120分钟边界已做分段/时间轴测试，未进行2小时付费语音调用。','No iOS build in this release. Near-limit splitting/timeline tests passed; a paid two-hour provider call was not performed.'))
    if version=='0.6.1':
        report['title']=words('已有功能的 PLAUD UI 对齐','PLAUD UI alignment for existing features')
        report['dependency']=words('共享后端 1.4.1，无新增迁移；生成流程和 Prompt 不变。本轮未调用 Azure / DeepSeek。','Shared backend 1.4.1 without new migrations; generation workflows and prompts unchanged. No Azure / DeepSeek calls in this release.')
    if version=='0.7.0':
        assert not baseline, 'MVP candidate cannot promote the baseline before physical acceptance'
        report['title']=words('Teno MVP双语界面候选：Android0.7.0 / Web0.2.0','Teno MVP bilingual candidate: Android0.7.0 / Web0.2.0')
        report['implementation']='implemented'
        report['changes']=[words('按MVP原型更新暖白绿视觉与中英切换；不重处理历史资料。','MVP visual refresh and Chinese/English switching without reprocessing existing content.')]
        report['modules']=[{'key':key,'scope':words(zh,en),'implementation':'implemented','verification':'partial','pending':words('实机与逐页视觉验收待完成','Physical-device and page-by-page visual acceptance remain pending')} for key,zh,en in [
            ('library','暖白绿视觉、三项导航、资料库与现有笔记简报','MVP theme, three tabs, library and existing-note brief'),
            ('summary','共用Notes/来源、版本、分享中心与导出','Shared Notes/Source, versions, sharing and exports'),
            ('recording','双语共享页面与原生通知；保留录音、密钥及队列','Bilingual UI/native notices; recordings, keys and queue preserved'),
            ('distribution','原签名Android候选、独立Web候选；已确认基线不变','Original-signer Android and independent Web candidates; confirmed baselines unchanged')]]
        evidence(qa/'full-runtime-report.json','0.6.2至候选原签名覆盖保留','Same-signer upgrade retention from 0.6.2','emulator',manifest['upgrade_runtime_checks'])
        evidence(qa/'regression-runtime-report.json','候选原生回归和系统选择器','Candidate native regression and system pickers','emulator',manifest['regression_runtime_checks'])
        installed=evidence(qa/'final-install-report.json','候选覆盖安装与冷启动','Candidate update install and cold launch','emulator')
        assert installed['apk_sha256']==manifest['sha256'] and not installed['uninstalled']
        evidence(qa/'backend-acceptance.json','已有后端只读兼容验证','Existing backend read-only compatibility','server')
        tests.append({'name':words('Flutter共享界面回归','Shared Flutter regression'),'status':'passed','environment':'unit','count':manifest['flutter_tests'],'source':release.name})
        report['pending'].append(words('按计划完成Safari、Magic4 Pro/JWD验收后再正式发布；不提升基线。','Formal release follows Safari/Magic4 Pro/JWD acceptance; no baseline promotion.'))
    if version=='0.7.1':
        report['title']=words('Android 0.7.1：登录错误提示修复包','Android 0.7.1: login error classification fix')
        report['implementation']='implemented'
        report['changes']=[words('登录401显示账号密码校验失败，不再一律改成会话过期；保留真实续期失败的独立提示。','Rejected sign-in credentials no longer appear as expired sessions; genuine refresh failures retain their own message.'),words('中英文错误提示、关闭用户名自动纠错；保留密码原始字符。','Chinese/English error messages and no username autocorrection; password characters are preserved exactly.')]
        report['modules']=[{'key':key,'scope':words(zh,en),'implementation':'implemented','verification':'partial','pending':words('真实手机复测待完成','Physical-phone retest pending')} for key,zh,en in [('sync','登录错误分类与中英提示','Login error classification and bilingual messages'),('library','覆盖安装保留账号、录音与设备密钥','Update retains account, recordings and device keys'),('distribution','原签名0.7.1修复包；当前正式基线0.7.0保持','Original-signer 0.7.1 fix; confirmed 0.7.0 baseline retained')]]
        report['dependency']=words('已有共享后端1.5.2；本轮没有部署后端或Web，不改变账号密码。','Existing backend 1.5.2; no backend/Web deployment or account password change.')
        report['pending']=[words('需在实际手机复测登录；修复错误提示不放宽凭据校验，不代表真实JWD验收通过。','Retest sign-in on the physical phone. Error-message correction does not bypass credentials or certify JWD hardware.')]
        for name,zh,en,count in [('full-runtime-report.json','0.7.0覆盖升级保留','Upgrade retention from 0.7.0',manifest['upgrade_runtime_checks']),('regression-runtime-report.json','最终APK原生回归','Final APK native regression',manifest['regression_runtime_checks']),('auth-errors-runtime-report.json','真实Android HTTP登录与续期错误分类','Android HTTP login/refresh classification',9)]:
            evidence(qa/name,zh,en,'emulator',count)
        evidence(qa/'final-install-report.json','原签名覆盖安装及冷启动','Signed update and cold launch','emulator')
        evidence(qa/'backend-acceptance.json','已有API只读兼容检查','Existing API read-only compatibility','server')
        tests.append({'name':words('Flutter完整回归','Complete Flutter regression'),'status':'passed','environment':'unit','count':manifest['flutter_tests'],'source':release.name})
    def asset(path,kind,zh,en):return {'path':str(path.resolve()),'kind':kind,'sha256':sha(path),'label':words(zh,en)}
    summary_path=output/f'Teno-{version}-android-evidence.txt'
    summary_path.write_text(json.dumps({'version':version,'platform':'android','source_commit':commit,'apk_sha256':manifest['sha256'],'physical_device_tested':False,'verification':summaries},ensure_ascii=False,indent=2),encoding='utf-8')
    files=[asset(apk,'apk','Android 原签名内测包','Original-signer Android release'),asset(summary_path,'evidence','Android 验证摘要与检查项','Android validation summary and checks')]
    if version=='0.6.0':
        files.append(asset(qa/'03-import-entry-android.png','screenshot','Android导入入口（模拟器）','Android import entry (emulator)'))
    screen=qa/('release-cold-start.png' if version=='0.4.4' else '04-final-login-android.png')
    if screen.exists(): files.append(asset(screen,'screenshot','Android 模拟器登录页','Android emulator login screen'))
    envelopes=[{'report':report,'files':files}]
    if manifest.get('ios'):
        ios=manifest['ios']; ipa=manifest_path.parent/ios['ipa']; assert sha(ipa)==ios['sha256'] and ipa.stat().st_size==ios['bytes']
        assert subprocess.check_output(['git','cat-file','-t',ios['source_commit']],cwd=ROOT,text=True).strip()=='commit'
        doc=json.loads((qa/'ios-ci-report.json').read_text()); assert doc['all_passed'] and doc['source_commit']==ios['source_commit'] and doc['ipa_sha256']==ios['sha256']
        ios_sources=[{'label':'iOS CI verification','reference':(qa/'ios-ci-report.json').relative_to(ROOT).as_posix(),'sha256':sha(qa/'ios-ci-report.json')}, {'label':'GitHub Actions','reference':ios['ci_run']},sources[0],{'label':'Release notes','reference':release.name,'sha256':sha(release)}, {'label':'iPhone installation guide','reference':'ios/INSTALL.txt','sha256':sha(ROOT/'ios/INSTALL.txt')}]
        ios_report={**report,'platform':'ios','commit':ios['source_commit'],'build_number':f"release-{version}-{sha(manifest_path)[:12]}-ios",'distribution':'unsigned','sources':ios_sources,
                    'title':words('iOS 原生宿主与 Flutter 共享界面','iOS native host and Flutter UI'),
                    'tests':[{'name':words('iOS 原生 XCTest','iOS native XCTest'),'status':'passed','count':doc['native_tests'],'environment':'simulator','source':ios_sources[0]['reference']},
                             {'name':words('iOS 样式页面自动测试','iOS styled page tests'),'status':'passed','count':manifest['ios_platform_widget_tests'],'environment':'unit','source':release.name},
                             {'name':words('模拟器启动与登录页核查','Simulator launch and login screen review'),'status':'passed','environment':'simulator','source':ios_sources[0]['reference']}],
                    'installation':words('未签名 IPA，需在自己的电脑上使用 AltStore Classic 等工具重签。不能直接点击安装；没有上传 App Store / TestFlight。最低 iOS 15。Apple 账号仅在本机输入，保持原账号与安装标识，覆盖更新而非先卸载。实际 iPhone 与 AltStore 安装尚待验收。','Unsigned IPA: sign locally with AltStore Classic or equivalent. Direct installation is not supported; this is not an App Store or TestFlight release. Requires iOS 15 or later. Enter your Apple account only locally and retain the same signing identity when updating. Physical iPhone and AltStore installation remain unverified.'),
                    'pending':[words('真实 iPhone 的麦克风、CoreBluetooth、后台上传、系统导入分享与 AltStore 重签安装待验收。','Physical iPhone microphone, CoreBluetooth, background uploads, system import/sharing and AltStore signing remain pending.')]}
        ios_report['modules']=[dict(m) for m in modules]
        ios_report['modules'][-1]={**ios_report['modules'][-1],'scope':words('ARM64 未签名 IPA，最低 iOS 15，需本地重签','Unsigned ARM64 IPA for iOS 15+, requires local signing'),'pending':words('真实 iPhone 与 AltStore 重签、覆盖安装验收','Validate iPhone signing, AltStore and upgrade installation')}
        ios_summary=output/f'Teno-{version}-ios-evidence.txt'
        ios_summary.write_text(json.dumps({k:doc[k] for k in ('all_passed','ci_run','source_commit','ipa_sha256','ipa_bytes','native_tests','native_test_failures','native_login_ocr_pass','unsigned','physical_iphone_tested','physical_jwd_tested','altstore_install_tested','test_boundary')},ensure_ascii=False,indent=2),encoding='utf-8')
        ios_files=[asset(ipa,'ipa','iOS 未签名内测包','Unsigned iOS internal release'),asset(ios_summary,'evidence','iOS 编译与模拟器验证摘要','iOS build and simulator summary')]
        ios_screen=qa/'05-final-login-ios.png'; assert sha(ios_screen)==doc['screenshot_sha256']
        ios_files.append(asset(ios_screen,'screenshot','iOS 原生模拟器登录页','Native iOS simulator login screen'))
        # Installation guide is an explicitly reviewed document, not a raw log.
        guide=output/f'Teno-{version}-ios-install.txt'; guide.write_text((ROOT/'ios/INSTALL.txt').read_text(encoding='utf-8'),encoding='utf-8')
        ios_files.append(asset(guide,'evidence','iPhone 安装步骤与验收范围','iPhone installation and acceptance guide'))
        envelopes.append({'report':ios_report,'files':ios_files})
    for envelope in envelopes:
        (output/f"{version}-{envelope['report']['platform']}.json").write_text(json.dumps(envelope,ensure_ascii=False,indent=2),encoding='utf-8')
    return envelopes


def main():
    p=argparse.ArgumentParser(); p.add_argument('--manifest',type=Path,required=True); p.add_argument('--credential',type=Path,default=Path.home()/'.ssh/teno-development-local.json')
    p.add_argument('--baseline',action='store_true'); p.add_argument('--prepare-only',action='store_true')
    p.add_argument('--output',type=Path,default=Path.home()/'.teno/development-releases');p.add_argument('--outbox',type=Path,default=Path.home()/'.teno/development-outbox');args=p.parse_args()
    envelopes=normalize(args.manifest,args.output,args.baseline)
    if not args.prepare_only:
        config=configuration(args.credential)
        for envelope in envelopes: send(envelope,config,args.outbox)
    print('Reviewed release reports prepared:',len(envelopes))


if __name__=='__main__':main()
