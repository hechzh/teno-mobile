"""Package the signed Automatic-language release from an explicit allowlist."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib,json,os,re,subprocess,zipfile
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[2];qa=Path(__file__).resolve().parent;dist=root/'dist'
server_qa=root.parent/'team-local/automatic-language-20261102'
sdk=Path.home()/'AppData/Local/Android/Sdk/build-tools/35.0.1';built=root/'app/build/outputs/apk/release/app-release.apk'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
env={**os.environ,'JAVA_HOME':'C:/Program Files/Android/Android Studio/jbr'}
signature=subprocess.check_output([str(sdk/'apksigner.bat'),'verify','--verbose','--print-certs',str(built)],env=env,text=True)
badging=subprocess.check_output([str(sdk/'aapt.exe'),'dump','badging',str(built)],text=True,encoding='utf-8')
certificate=re.search(r'certificate SHA-256 digest: ([a-f0-9]+)',signature).group(1)
assert certificate=='56291d8fefaf737b522f88b075960ecddfe8f2d1e6794d538d4f46ad2b1d1291'
assert "name='com.teno.app' versionCode='9' versionName='0.4.4'" in badging
assert 'application-debuggable' not in badging
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
assert sha(dist/'Teno-0.4.3.apk')=='2cab978ec78b5b54f94ca36fe0e5ad055b5d1dd1da1592d5c085881f74892a9e'
reports=[json.loads((qa/(name+'-automatic-report.json')).read_text(encoding="utf-8")) for name in ('normal','compact')]
assert all(r['all_passed'] for r in reports)
install=json.loads((qa/'release-install-report.json').read_text(encoding="utf-8"));visual=json.loads((qa/'visual-review.json').read_text(encoding="utf-8"))
assert install['all_passed'] and install['apk_sha256']==sha(built) and install['upgrade_from']=='0.4.3' and not install['uninstalled']
assert visual['visual_review_passed'] and len(visual['screens_viewed'])>=10
backend=json.loads((server_qa/'backend-tests.json').read_text(encoding="utf-8"));provider=json.loads((server_qa/'provider-report.json').read_text(encoding="utf-8"));live=json.loads((server_qa/'live-acceptance.json').read_text(encoding="utf-8"))
assert backend['all_passed'] and provider['all_passed'] and live['all_passed']
issues=ET.parse(root/'app/build/reports/lint-results-release.xml').getroot().findall('issue')
errors=sum(i.get('severity') in ('Error','Fatal') for i in issues);warnings=sum(i.get('severity')=='Warning' for i in issues);assert not errors
(qa/'release-signature.txt').write_text(signature);(qa/'release-badging.txt').write_text(badging,encoding='utf-8')
apk=dist/'Teno-0.4.4.apk';apk.write_bytes(built.read_bytes());source=dist/'Teno-0.4.4-source.zip'
allowed=[]
for folder in ('app/src','gradle','tests'):allowed.extend(p for p in (root/folder).rglob('*') if p.is_file())
for name in ('build.gradle','settings.gradle','gradle.properties','gradlew','gradlew.bat','app/build.gradle','README.md','RELEASE-0.4.4.txt','VENDOR-JWD.md','LUCIDE-LICENSE.txt','THIRD-PARTY-NOTICES.txt'):
    if (root/name).is_file():allowed.append(root/name)
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as out:
    for p in sorted(set(allowed)):
        assert p.name.lower() not in ('agents.md','.env','local.properties')
        assert p.suffix.lower() not in ('.pem','.jks','.keystore','.apk','.wav','.m4a','.mp3')
        out.write(p,'Teno-0.4.4/'+p.relative_to(root).as_posix())
secrets=[]
handoff=root.parent.parent/'AGENTS.md'
if handoff.is_file():secrets.extend(m.encode() for m in re.findall(r'(?:AZURE_SPEECH_KEY|DEEPSEEK_API_KEY)=([^\s`]+)',handoff.read_text(encoding='utf-8')) if len(m)>12)
accounts=Path.home()/'.ssh/pocket-test-accounts.json'
if accounts.is_file():secrets.extend(a['password'].encode() for a in json.loads(accounts.read_text(encoding='utf-8'))['accounts'])
for archive in (apk,source):
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            data=z.read(name);assert not any(secret in data for secret in secrets),'Private credential detected'
            if archive==apk:assert not any(m in data for m in (b'AutomaticInstrumentation',b'automatic-loopback-fixture',b'FlowInstrumentation',b'NavigationInstrumentation',b'RecoveryInstrumentation',b'FixtureKey123456',b'V3Instrumentation',b'JwdInstrumentation',b'RecorderHarnessActivity')),'Test fixture found in release'
manifest={'application':'Teno','version':'0.4.4','version_code':9,'package':'com.teno.app','built_at_beijing':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
    'apk':apk.name,'bytes':apk.stat().st_size,'sha256':sha(apk),'source_zip':source.name,'source_zip_sha256':sha(source),'source_files':len(set(allowed)),
    'signer_sha256':certificate,'same_signer_as_previous_release':True,'debuggable':False,'apk_signature_v2_verified':True,'minimum_android_api':26,'target_android_api':35,
    'tested_android_api':35,'release_upgrade_install_and_cold_launch_passed':True,'upgraded_from':'0.4.3','speech_language':'auto','language_picker_removed':True,
    'default_capture_source':'recorder','phone_capture_entry':'secondary text link','ui_checks_passed':sum(len(r['checks']) for r in reports),'ui_screenshots':sum(len(r['screens']) for r in reports),
    'screenshots_visually_reviewed':len(visual['screens_viewed']),'test_package':'com.teno.app.autoverification','emulator_phone_capture_and_local_wav_save_passed':True,
    'backend_version':'1.2.2','backend_checks_passed':backend['passed'],'real_azure_provider_checks_passed':len(provider['results']),'production_https_websocket_checks_passed':len(live['checks']),
    'realtime_candidates':['zh-CN','en-US'],'file_language_identification':'multilingual','live_preview_reused_as_final':False,'summary_language_independent':True,
    'lint_errors':errors,'lint_warnings':warnings,'jwd_hardware_tested':False,'magic4_pro_tested':False,'word_error_rate_evaluated':False,
    'no_test_runners_in_apk':True,'private_credential_scan_passed':True,'source_archive_excludes_private_configuration':True,'verification_gallery':'../verification/v0.4.4/automatic-review.html'}
for name in ('release-manifest.json','Teno-0.4.4-release-manifest.json'):(dist/name).write_bytes(json.dumps(manifest,ensure_ascii=False,indent=2).encode('utf-8'))
(qa/'release-verification.json').write_bytes(json.dumps(manifest,indent=2).encode())
(dist/'SHA256SUMS.txt').write_bytes(('\n'.join(sha(p)+'  '+p.name for p in sorted(dist.iterdir()) if p.suffix in ('.apk','.zip'))+'\n').encode())
print(json.dumps({'apk':str(apk),'sha256':sha(apk),'bytes':apk.stat().st_size,'source_files':len(set(allowed)),'lint_errors':errors,'lint_warnings':warnings}))
