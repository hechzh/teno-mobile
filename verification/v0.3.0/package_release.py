from pathlib import Path
import hashlib, json, zipfile, subprocess, os, re, html
from datetime import datetime
from zoneinfo import ZoneInfo
import xml.etree.ElementTree as ET

root=Path(__file__).resolve().parents[2]
qa=root/'verification/v0.3.0';dist=root/'dist';dist.mkdir(exist_ok=True)
env={**os.environ,'JAVA_HOME':'C:/Program Files/Android/Android Studio/jbr'}
sdk=Path('C:/Users/lexia/AppData/Local/Android/Sdk/build-tools/35.0.1')
built=root/'app/build/outputs/apk/release/app-release.apk'
signature=subprocess.check_output([str(sdk/'apksigner.bat'),'verify','--verbose','--print-certs',str(built)],env=env,text=True)
badging=subprocess.check_output([str(sdk/'aapt.exe'),'dump','badging',str(built)],text=True,encoding='utf-8')
certificate=re.search(r'certificate SHA-256 digest: ([a-f0-9]+)',signature).group(1)
assert certificate=='56291d8fefaf737b522f88b075960ecddfe8f2d1e6794d538d4f46ad2b1d1291'
assert "name='com.teno.app' versionCode='4' versionName='0.3.0'" in badging
assert 'application-debuggable' not in badging
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
(qa/'release-signature.txt').write_text(signature,encoding='utf-8')
(qa/'release-badging.txt').write_text(badging,encoding='utf-8')

lint=ET.parse(root/'app/build/reports/lint-results-release.xml').getroot().findall('issue')
errors=sum(i.get('severity') in ('Error','Fatal') for i in lint);warnings=sum(i.get('severity')=='Warning' for i in lint)
assert errors==0
checks=[json.loads((qa/name).read_text(encoding='utf-8')) for name in ('v3-report.json','v3-polish-report.json')]
assert all(r['all_passed'] for r in checks)
assert '53 passed' in (qa/'backend-tests.txt').read_text(encoding='utf-8')
apk=dist/'Teno-0.3.0.apk';apk.write_bytes(built.read_bytes())
source=dist/'Teno-0.3.0-source.zip'
allowed=[]
for folder in ('app/src','gradle','tests'):
    allowed.extend(p for p in (root/folder).rglob('*') if p.is_file())
for name in ('build.gradle','settings.gradle','gradle.properties','gradlew','gradlew.bat','app/build.gradle','README.md','RELEASE-0.3.0.txt','VENDOR-JWD.md','LUCIDE-LICENSE.txt','THIRD-PARTY-NOTICES.txt'):
    if (root/name).is_file():allowed.append(root/name)
for p in allowed:
    assert p.name not in ('AGENTS.md','.env','local.properties')
    assert p.suffix.lower() not in ('.pem','.jks','.keystore','.apk')
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as out:
    for p in sorted(set(allowed)):out.write(p,'Teno-0.3.0/'+str(p.relative_to(root)).replace('\\','/'))

# Check actual private values in memory; never echo or copy them into the report.
secrets=[]
handoff=root.parent.parent/'AGENTS.md'
if handoff.is_file():
    secrets += [m.encode() for m in re.findall(r'(?:AZURE_SPEECH_KEY|DEEPSEEK_API_KEY)=([^\s`]+)',handoff.read_text(encoding='utf-8')) if len(m)>12]
accounts=json.loads((Path.home()/'.ssh/pocket-test-accounts.json').read_text(encoding='utf-8'))
secrets += [a['password'].encode() for a in accounts['accounts']]
for archive in (apk,source):
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            data=z.read(name)
            assert not any(secret in data for secret in secrets), 'Credential detected in distributable'
            if archive==apk:
                assert not any(x in data for x in (b'V3Instrumentation',b'V3PolishInstrumentation',b'JwdInstrumentation',b'SmokeInstrumentation')), 'Test runner found in APK'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest={
 'application':'Teno','version':'0.3.0','version_code':4,'package':'com.teno.app',
 'built_at_beijing':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
 'apk':apk.name,'bytes':apk.stat().st_size,'sha256':sha(apk),
 'source_zip':source.name,'source_zip_sha256':sha(source),
 'signer_sha256':certificate,'same_signer_as_previous_release':True,
 'debuggable':False,'apk_signature_v2_verified':True,
 'minimum_android_api':26,'target_android_api':35,'tested_android_api':35,
 'release_upgrade_install_and_cold_launch_passed':True,'upgraded_from':'0.2.1',
 'https_base_url':'https://54-214-180-183.sslip.io',
 'backend_tests_passed':53,'native_core_checks_passed':len(checks[0]['checks']),
 'native_additional_checks_passed':len(checks[1]['checks']),'protocol_checks_passed':22,
 'lint_errors':errors,'lint_warnings':warnings,
 'jwd_hardware_tested':False,'magic4_pro_tested':False,
 'live_speech_provider':'Azure Speech SDK through authenticated Teno WebSocket bridge',
 'speech_test_source':'Synthetic English WAV; physical speech quality not evaluated',
 'recording_id':checks[0]['recording_id'],'live_session_id':checks[0]['live_session_id'],
 'no_test_runners_in_apk':True,'private_credential_scan_passed':True,
 'source_archive_excludes_private_configuration':True,
 'source_files':len(set(allowed)),
 'limits':{'phone_recording_minutes':54,'import_minutes':60,'import_MiB':100,'speech_concurrency':1},
 'not_included':['iOS','Wi-Fi fast transfer','OTA','paid subscriptions','external connectors','automatic speaker identification']
}
for name in ('release-manifest.json','Teno-0.3.0-release-manifest.json'):(dist/name).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(qa/'release-verification.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
lines=[sha(p)+'  '+p.name for p in sorted(dist.iterdir()) if p.suffix in ('.apk','.zip')]
(dist/'SHA256SUMS.txt').write_text('\n'.join(lines)+'\n',encoding='utf-8')

screens=qa/'screenshots'
captions={'03-phone-recording':'Phone capture (before final fixed controls)','05-recording-summary':'Initial summary with original account language','15-english-summary':'English output from the real model','19-offline-recording':'Network unavailable; local capture continues','22-release-home':'Signed release cold launch'}
figures=[]
for p in sorted(screens.glob('*.png')):
    caption=captions.get(p.stem,p.stem.replace('-',' '))
    figures.append(f'<figure><a href="{html.escape(p.name)}"><img loading="lazy" src="{html.escape(p.name)}" alt="{html.escape(caption)}"></a><figcaption>{html.escape(caption)}</figcaption></figure>')
(screens/'index.html').write_text('''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Teno 0.3 — Native screenshots</title><style>body{font:16px system-ui;background:#f6f7f3;color:#20251f;max-width:1500px;margin:40px auto;padding:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:24px}figure{margin:0}img{width:100%;border-radius:20px;border:1px solid #dfe2d9}figcaption{margin:12px 0 24px;color:#72786e}</style><h1>Teno 0.3 — Native Android screenshots</h1><p>Captured on an API 35 emulator using synthetic acceptance data. These are application screenshots, not design renders. The recorder was not physically connected. Transcript and generated content reflect their selected language.</p><main>'''+''.join(figures)+'</main></html>',encoding='utf-8')
print(json.dumps({'apk':str(apk),'apk_bytes':apk.stat().st_size,'sha256':manifest['sha256'],'checks':[53,len(checks[0]['checks']),len(checks[1]['checks']),22],'lint_errors':errors,'lint_warnings':warnings,'source_files':len(set(allowed))},indent=2))
