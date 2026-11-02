"""Package the signed recorder-first entry from an explicit source allowlist."""
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, os, re, subprocess, zipfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[2]
qa = Path(__file__).resolve().parent
dist = root / 'dist'
sdk = Path.home() / 'AppData/Local/Android/Sdk/build-tools/35.0.1'
built = root / 'app/build/outputs/apk/release/app-release.apk'
env = {**os.environ, 'JAVA_HOME': 'C:/Program Files/Android/Android Studio/jbr'}
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
signature = subprocess.check_output([str(sdk / 'apksigner.bat'), 'verify', '--verbose', '--print-certs', str(built)], env=env, text=True)
badging = subprocess.check_output([str(sdk / 'aapt.exe'), 'dump', 'badging', str(built)], text=True, encoding='utf-8')
certificate = re.search(r'certificate SHA-256 digest: ([a-f0-9]+)', signature).group(1)
assert certificate == '56291d8fefaf737b522f88b075960ecddfe8f2d1e6794d538d4f46ad2b1d1291'
assert "name='com.teno.app' versionCode='8' versionName='0.4.3'" in badging
assert 'application-debuggable' not in badging
assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
assert sha(dist / 'Teno-0.4.2.apk') == '113ea049c313734a4228f886c81f95de304de18b8e0a437a622f7ef9f55eebf4'
entry = json.loads((qa / 'flow-summary.json').read_text())
installation = json.loads((qa / 'release-install-report.json').read_text())
visual = json.loads((qa / 'visual-review.json').read_text(encoding='utf-8'))
assert entry['all_passed'] and len(entry['configurations']) == 2
assert sum(c['checks_passed'] for c in entry['configurations']) == 96
assert sum(c['screenshots'] for c in entry['configurations']) == 26
assert installation['all_passed'] and installation['apk_sha256'] == sha(built)
assert installation['upgrade_from'] == '0.4.2' and not installation['uninstalled']
assert visual['visual_review_passed'] and len(visual['screens_viewed']) >= 20
recovery = json.loads((qa / 'recovery-summary.json').read_text())
assert recovery['all_passed'] and sum(len(p['checks']) for p in recovery['phases']) == 8
assert 'ALL 22 CHECKS PASSED' in (qa / 'protocol-tests.txt').read_text(encoding='utf-8-sig')
issues = ET.parse(root / 'app/build/reports/lint-results-release.xml').getroot().findall('issue')
errors = sum(i.get('severity') in ('Error', 'Fatal') for i in issues)
warnings = sum(i.get('severity') == 'Warning' for i in issues)
assert errors == 0
(qa / 'release-signature.txt').write_text(signature)
(qa / 'release-badging.txt').write_text(badging, encoding='utf-8')
apk = dist / 'Teno-0.4.3.apk'
apk.write_bytes(built.read_bytes())
source = dist / 'Teno-0.4.3-source.zip'
allowed = []
for folder in ('app/src', 'gradle', 'tests'):
    allowed.extend(p for p in (root / folder).rglob('*') if p.is_file())
for name in ('build.gradle', 'settings.gradle', 'gradle.properties', 'gradlew', 'gradlew.bat', 'app/build.gradle', 'README.md', 'RELEASE-0.4.3.txt', 'VENDOR-JWD.md', 'LUCIDE-LICENSE.txt', 'THIRD-PARTY-NOTICES.txt'):
    if (root / name).is_file():
        allowed.append(root / name)
with zipfile.ZipFile(source, 'w', zipfile.ZIP_DEFLATED) as out:
    for p in sorted(set(allowed)):
        assert p.name.lower() not in ('agents.md', '.env', 'local.properties')
        assert p.suffix.lower() not in ('.pem', '.jks', '.keystore', '.apk', '.wav', '.m4a', '.mp3')
        out.write(p, 'Teno-0.4.3/' + p.relative_to(root).as_posix())

# Check protected local values without printing or persisting their contents.
secrets = []
handoff = root.parent.parent / 'AGENTS.md'
if handoff.is_file():
    secrets.extend(m.encode() for m in re.findall(r'(?:AZURE_SPEECH_KEY|DEEPSEEK_API_KEY)=([^\s`]+)', handoff.read_text(encoding='utf-8')) if len(m) > 12)
account_file = Path.home() / '.ssh/pocket-test-accounts.json'
if account_file.is_file():
    secrets.extend(a['password'].encode() for a in json.loads(account_file.read_text(encoding='utf-8'))['accounts'])
for archive in (apk, source):
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            data = z.read(name)
            assert not any(secret in data for secret in secrets), 'Private credential detected'
            if archive == apk:
                assert not any(marker in data for marker in (b'FlowInstrumentation', b'RecoveryInstrumentation', b'RecorderHarnessActivity', b'loopback-flow-fixture', b'offline-fixture-only', b'FixtureKey123456', b'NavigationInstrumentation', b'RecordingEntryInstrumentation', b'Layout fixture recorder', b'V4Instrumentation', b'V3Instrumentation', b'JwdInstrumentation', b'SmokeInstrumentation', b'local-fixture-only')), 'Test fixture found'

manifest = {
    'application': 'Teno', 'version': '0.4.3', 'version_code': 8, 'package': 'com.teno.app',
    'built_at_beijing': datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(),
    'apk': apk.name, 'bytes': apk.stat().st_size, 'sha256': sha(apk),
    'source_zip': source.name, 'source_zip_sha256': sha(source), 'source_files': len(set(allowed)),
    'signer_sha256': certificate, 'same_signer_as_previous_release': True, 'debuggable': False,
    'apk_signature_v2_verified': True, 'minimum_android_api': 26, 'target_android_api': 35,
    'tested_android_api': 35, 'release_upgrade_install_and_cold_launch_passed': True, 'upgraded_from': '0.4.2',
    'release_cold_launch_screen': 'Sign in', 'default_capture_source': 'recorder', 'phone_capture_entry': 'secondary text link',
    'recording_flow_configurations': entry['configurations'], 'recording_flow_checks_passed': 96,
    'recording_flow_screenshots': 26, 'screenshots_visually_reviewed': len(visual['screens_viewed']),
    'test_package': entry['test_package'], 'fixture_scope': 'Loopback HTTP; actual emulator PCM capture; synthetic recorder transport replies',
    'emulator_phone_capture_and_local_wav_save_passed': True, 'device_transport_is_synthetic': True, 'offline_relaunch_checks_passed': 8, 'protocol_checks_passed': 22,
    'lint_errors': errors, 'lint_warnings': warnings, 'backend_changed': False,
    'backend_retested_this_release': False, 'cloud_speech_retested_this_release': False,
    'jwd_hardware_tested': False, 'magic4_pro_tested': False,
    'no_test_runners_in_apk': True, 'private_credential_scan_passed': True,
    'source_archive_excludes_private_configuration': True,
    'verification_gallery': '../verification/v0.4.3/flow-review.html'
}
for name in ('release-manifest.json', 'Teno-0.4.3-release-manifest.json'):
    (dist / name).write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
(qa / 'release-verification.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
(dist / 'SHA256SUMS.txt').write_text('\n'.join(sha(p) + '  ' + p.name for p in sorted(dist.iterdir()) if p.suffix in ('.apk', '.zip')) + '\n')
print(json.dumps({'apk': str(apk), 'sha256': sha(apk), 'MiB': round(apk.stat().st_size / 2**20, 2), 'source_files': len(set(allowed)), 'lint_errors': errors, 'lint_warnings': warnings}))
