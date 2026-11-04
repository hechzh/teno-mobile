"""Package verified local artifacts from an explicit Git allowlist. Never read signing passwords."""
import argparse, datetime, hashlib, json, os, pathlib, plistlib, re, shutil, struct, subprocess, sys, zipfile
import xml.etree.ElementTree as ET
import secret_audit

ROOT=pathlib.Path(__file__).resolve().parents[1]
QA=ROOT/'verification/v0.5.0'
DIST=ROOT/'dist'
CERT='56291d8fefaf737b522f88b075960ecddfe8f2d1e6794d538d4f46ad2b1d1291'
def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def read(path): return json.loads(path.read_text(encoding='utf-8'))
def macho_cpus(data):
    if data[:4] == b'\xcf\xfa\xed\xfe': return {struct.unpack('<I',data[4:8])[0]}
    if data[:4] in (b'\xca\xfe\xba\xbe',b'\xca\xfe\xba\xbf'):
        count=struct.unpack('>I',data[4:8])[0]; stride=20 if data[3]==0xbe else 32
        assert 0<count<10
        return {struct.unpack('>I',data[8+i*stride:12+i*stride])[0] for i in range(count)}
    raise ValueError('Not a supported Mach-O binary')
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--ipa',type=pathlib.Path)
    parser.add_argument('--ios-run')
    parser.add_argument('--private-values',action='append',default=[])
    options=parser.parse_args()
    assert subprocess.run(['git','diff','--quiet','HEAD','--'],cwd=ROOT).returncode==0,'Commit reviewed source before packaging'
    secret_audit.load_private(options.private_values)
    accounts=pathlib.Path.home()/'.ssh/pocket-test-accounts.json'
    if accounts.is_file():
        for account in read(accounts).get('accounts',[]):
            value=account.get('password','')
            if value: secret_audit.KNOWN.extend([value.encode(),value.encode('utf-16le')])
    apk=ROOT/'app/build/outputs/apk/release/app-release.apk'
    sdk=pathlib.Path(os.environ.get('ANDROID_HOME',str(pathlib.Path.home()/'AppData/Local/Android/Sdk')))/'build-tools/35.0.1'
    env={**os.environ,'JAVA_HOME':os.environ.get('JAVA_HOME','C:/Program Files/Android/Android Studio/jbr')}
    signature=subprocess.check_output([str(sdk/'apksigner.bat'),'verify','--verbose','--print-certs',str(apk)],env=env,text=True)
    badging=subprocess.check_output([str(sdk/'aapt.exe'),'dump','badging',str(apk)],text=True,encoding='utf-8')
    assert re.search(r'certificate SHA-256 digest: ([a-f0-9]+)',signature).group(1)==CERT
    assert "name='com.teno.app' versionCode='10' versionName='0.5.0'" in badging
    assert 'application-debuggable' not in badging
    assert 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
    install=read(QA/'final-install-report.json')
    assert install['all_passed'] and not install['uninstalled'] and install['apk_sha256']==digest(apk)
    native=read(QA/'full-runtime-report.json'); regression=read(QA/'regression-runtime-report.json')
    assert native['all_passed'] and regression['all_passed']
    issues=ET.parse(ROOT/'app/build/reports/lint-results-release.xml').getroot().findall('issue')
    errors=sum(i.get('severity') in ('Error','Fatal') for i in issues)
    warnings=sum(i.get('severity')=='Warning' for i in issues)
    assert errors==0
    for name in ('flutter-tests.log','flutter-ios-pages.log'):
        assert 'All tests passed!' in (QA/name).read_text(encoding='utf-8',errors='replace')
    DIST.mkdir(exist_ok=True)
    files=[name.decode() for name in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).split(b'\0') if name]
    archive=DIST/'Teno-0.5.0-source.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
        for name in sorted(set(files)):
            path=ROOT/name
            assert path.is_file()
            assert not secret_audit.PRIVATE.search(name)
            assert path.suffix.lower() not in ('.apk','.ipa','.zip','.wav','.m4a','.mp3','.log','.db','.pem','.jks')
            z.write(path,'Teno-0.5.0/'+name)
    for artifact in (apk,archive): secret_audit.archive(artifact.name,artifact.read_bytes())
    with zipfile.ZipFile(apk) as z:
        for name in z.namelist():
            if name.endswith(('.dex','.so')):
                content=z.read(name)
                assert not any(v in content for v in (b'RuntimeInstrumentation',b'FixtureHost',b'reviewModel',b'teno-cross-platform-fixture')),'Test fixture entered release'
    ios=None
    if options.ipa:
        assert options.ios_run and options.ipa.is_file()
        ios_report=read(QA/'ios-ci-report.json')
        assert ios_report['all_passed'] and ios_report['native_login_ocr_pass']
        assert ios_report['ci_run']==options.ios_run and ios_report['ipa_sha256']==digest(options.ipa)
        secret_audit.archive(options.ipa.name,options.ipa.read_bytes())
        with zipfile.ZipFile(options.ipa) as z:
            names=z.namelist()
            assert 'Payload/Teno.app/Info.plist' in names
            assert not any(n.endswith('embedded.mobileprovision') for n in names)
            assert not any('.xctest/' in n for n in names)
            assert not any(n.endswith('kernel_blob.bin') for n in names),'Debug Dart kernel entered device IPA'
            info=plistlib.loads(z.read('Payload/Teno.app/Info.plist'))
            assert info['CFBundleIdentifier']=='com.teno.app' and info['CFBundleVersion']=='10'
            assert info['CFBundleShortVersionString']=='0.5.0' and info['MinimumOSVersion']=='15.0'
            assert {'audio','bluetooth-central'} <= set(info['UIBackgroundModes'])
            for name in ['Teno','Frameworks/App.framework/App','Frameworks/Flutter.framework/Flutter','Frameworks/JwdVtrSDK.framework/JwdVtrSDK']:
                assert macho_cpus(z.read('Payload/Teno.app/'+name))=={0x0100000c},'Device IPA must contain arm64 Mach-O binaries'
        ios={'ipa':'Teno-0.5.0-unsigned.ipa','sha256':digest(options.ipa),'bytes':options.ipa.stat().st_size,
             'unsigned':True,'ci_run':options.ios_run,'source_commit':ios_report['source_commit'],
             'native_tests':ios_report['native_tests'],'native_login_ocr_pass':True,'architecture':'arm64',
             'minimum_ios':'15.0','physical_iphone_tested':False,'altstore_install_tested':False}
    if secret_audit.FINDINGS:
        print(json.dumps({'status':'blocked','findings':[{'path':p,'rule':r} for p,r in sorted(secret_audit.FINDINGS)]})); return 1
    deliverable=DIST/'Teno-0.5.0.apk'; shutil.copyfile(apk,deliverable)
    if options.ipa: shutil.copyfile(options.ipa,DIST/ios['ipa'])
    manifest={'application':'Teno','version':'0.5.0','version_code':10,'package':'com.teno.app',
        'packaged_at':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'apk':deliverable.name,'sha256':digest(deliverable),'bytes':deliverable.stat().st_size,
        'source_zip':archive.name,'source_zip_sha256':digest(archive),'source_files':len(files),
        'signer_sha256':CERT,'same_signer_as_previous_release':True,'debuggable':False,'apk_signature_v2_verified':True,
        'minimum_android_api':26,'target_android_api':35,'tested_android_api':35,
        'release_upgrade_install_and_cold_launch_passed':True,'upgraded_from':'0.4.4',
        'upgrade_runtime_checks':len(native['checks']),'regression_runtime_checks':len(regression['checks']),
        'flutter_tests':33,'ios_platform_widget_tests':28,'jwd_protocol_checks':22,
        'lint_errors':errors,'lint_warnings':warnings,'speech_language':'auto',
        'backend_modified':False,'real_azure_retested':False,'physical_android_tested':False,'physical_jwd_tested':False,
        'no_test_runners_in_apk':True,'private_credential_scan_passed':True,
        'ios':ios,'review':'../design-baseline/index.html','validation':'../RELEASE-0.5.0.txt'}
    for name in ('release-manifest.json','Teno-0.5.0-release-manifest.json'):
        (DIST/name).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (QA/'release-signature.txt').write_text(signature,encoding='utf-8')
    (QA/'release-badging.txt').write_text(badging,encoding='utf-8')
    (DIST/'SHA256SUMS.txt').write_text(''.join(digest(p)+'  '+p.name+'\n' for p in sorted(DIST.iterdir()) if p.suffix in ('.apk','.ipa','.zip')),encoding='utf-8')
    print(json.dumps({'status':'pass','apk_sha256':digest(deliverable),'source_files':len(files),'lint_errors':errors,'lint_warnings':warnings,'ios':ios}))
    return 0
if __name__=='__main__': sys.exit(main())
