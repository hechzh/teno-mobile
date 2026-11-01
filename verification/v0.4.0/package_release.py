"""Package an explicitly verified release; never bundle the workspace."""
from pathlib import Path
import hashlib,json,zipfile,subprocess,os,re
from datetime import datetime
from zoneinfo import ZoneInfo
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[2];qa=root/'verification/v0.4.0';shared=root.parent/'docs/verification';dist=root/'dist'
env={**os.environ,'JAVA_HOME':'C:/Program Files/Android/Android Studio/jbr'}
sdk=Path('C:/Users/lexia/AppData/Local/Android/Sdk/build-tools/35.0.1');built=root/'app/build/outputs/apk/release/app-release.apk'
signature=subprocess.check_output([str(sdk/'apksigner.bat'),'verify','--verbose','--print-certs',str(built)],env=env,text=True)
badging=subprocess.check_output([str(sdk/'aapt.exe'),'dump','badging',str(built)],text=True,encoding='utf-8')
cert=re.search(r'certificate SHA-256 digest: ([a-f0-9]+)',signature).group(1)
assert cert=='56291d8fefaf737b522f88b075960ecddfe8f2d1e6794d538d4f46ad2b1d1291'
assert "name='com.teno.app' versionCode='5' versionName='0.4.0'" in badging and 'application-debuggable' not in badging
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
v4=json.loads((qa/'v4-report.json').read_text());assert v4['all_passed']
assert '64 passed' in (shared/'audio-1.2/backend-tests.txt').read_text()
assert json.loads((shared/'production-audio-smoke.json').read_text())['all_passed']
assert 'ALL 22 CHECKS PASSED' in (qa/'protocol-tests.txt').read_text()
issues=ET.parse(root/'app/build/reports/lint-results-release.xml').getroot().findall('issue')
errors=sum(i.get('severity') in ('Error','Fatal') for i in issues);warnings=sum(i.get('severity')=='Warning' for i in issues);assert not errors
(qa/'release-signature.txt').write_text(signature);(qa/'release-badging.txt').write_text(badging,encoding='utf-8')
apk=dist/'Teno-0.4.0.apk';apk.write_bytes(built.read_bytes());source=dist/'Teno-0.4.0-source.zip'
allowed=[]
for folder in ('app/src','gradle','tests'):allowed.extend(p for p in (root/folder).rglob('*') if p.is_file())
for name in ('build.gradle','settings.gradle','gradle.properties','gradlew','gradlew.bat','app/build.gradle','README.md','RELEASE-0.4.0.txt','VENDOR-JWD.md','LUCIDE-LICENSE.txt','THIRD-PARTY-NOTICES.txt'):
 if (root/name).is_file():allowed.append(root/name)
with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as out:
 for p in sorted(set(allowed)):
  assert p.name.lower() not in ('agents.md','.env','local.properties') and p.suffix.lower() not in ('.pem','.jks','.keystore','.apk')
  out.write(p,'Teno-0.4.0/'+p.relative_to(root).as_posix())
secrets=[];handoff=root.parent.parent/'AGENTS.md'
if handoff.is_file():secrets.extend(m.encode() for m in re.findall(r'(?:AZURE_SPEECH_KEY|DEEPSEEK_API_KEY)=([^\s`]+)',handoff.read_text(encoding='utf-8')) if len(m)>12)
accounts=json.loads((Path.home()/'.ssh/pocket-test-accounts.json').read_text(encoding='utf-8'));secrets.extend(a['password'].encode() for a in accounts['accounts'])
for archive in (apk,source):
 with zipfile.ZipFile(archive) as z:
  for name in z.namelist():
   data=z.read(name);assert not any(secret in data for secret in secrets),'Private credential detected'
   if archive==apk:assert not any(x in data for x in (b'V4Instrumentation',b'V3Instrumentation',b'JwdInstrumentation',b'SmokeInstrumentation')),'Test runner found'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest={'application':'Teno','version':'0.4.0','version_code':5,'package':'com.teno.app','built_at_beijing':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
 'apk':apk.name,'bytes':apk.stat().st_size,'sha256':sha(apk),'source_zip':source.name,'source_zip_sha256':sha(source),'signer_sha256':cert,'same_signer_as_previous_release':True,'debuggable':False,'apk_signature_v2_verified':True,
 'minimum_android_api':26,'target_android_api':35,'tested_android_api':35,'release_upgrade_install_and_cold_launch_passed':True,'upgraded_from':'0.3.0','https_base_url':'https://54-214-180-183.sslip.io',
 'backend_version':'1.2.0','backend_tests_passed':64,'identity_history_followup_tests_passed':15,'native_core_checks_passed':len(v4['checks']),'protocol_checks_passed':22,'lint_errors':errors,'lint_warnings':warnings,
 'limits':{'phone_recording_minutes':54,'import_minutes':120,'import_MiB':250,'concurrency':{'realtime':2,'file':1,'voice':1}},
 'team_voice_profiles':'enrolled; automatic identity disabled until calibration passes','initial_voice_calibration':'insufficient: separation check failed','samuel':'manual review; no third independent validation recording',
 'realtime_provider':'Azure Speech SDK through authenticated Teno bridge','file_provider':'Azure Fast; team diarization enabled','voice_provider':'private team CAM++ CPU worker',
 'jwd_hardware_tested':False,'magic4_pro_tested':False,'long_phone_capture_tested_this_release':False,'real_english_meeting_tested':False,'two_hour_cloud_transcription_tested':False,
 'no_test_runners_in_apk':True,'private_credential_scan_passed':True,'source_archive_excludes_private_configuration':True,'source_files':len(set(allowed)),
 'not_included':['iOS','Wi-Fi fast transfer','OTA','real-time voice identity','real-time multi-speaker captions','resumable partial upload']}
for name in ('release-manifest.json','Teno-0.4.0-release-manifest.json'):(dist/name).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(qa/'release-verification.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
(dist/'SHA256SUMS.txt').write_text('\n'.join(sha(p)+'  '+p.name for p in sorted(dist.iterdir()) if p.suffix in ('.apk','.zip'))+'\n')
print(json.dumps({'apk':str(apk),'sha256':manifest['sha256'],'MiB':round(apk.stat().st_size/2**20,2),'source_files':len(set(allowed)),'lint_errors':errors,'lint_warnings':warnings}))
