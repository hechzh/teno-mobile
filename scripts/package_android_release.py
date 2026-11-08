"""Independent Android packaging; evidence and version are never inherited from iOS."""
import datetime, hashlib, json, os, pathlib, re, shutil, subprocess, zipfile
import xml.etree.ElementTree as ET
import secret_audit
from report_development import ROOT, sha

CERT='56291d8fefaf737b522f88b075960ecddfe8f2d1e6794d538d4f46ad2b1d1291'
def read(path):return json.loads(path.read_text(encoding='utf-8'))

def package(version,evidence_dir=None,private_values=()):
    build=(ROOT/'app/build.gradle').read_text();code=int(re.search(r'versionCode\s+(\d+)',build)[1])
    assert re.search(r"versionName\s+['\"]([^'\"]+)",build)[1]==version
    assert subprocess.run(['git','diff','--quiet','HEAD','--'],cwd=ROOT).returncode==0,'Commit reviewed source before packaging'
    qa=pathlib.Path(evidence_dir) if evidence_dir else ROOT/'verification'/('v'+version)
    assert qa.resolve()!=ROOT/'verification/v0.5.0'
    secret_audit.load_private(private_values)
    account_file=pathlib.Path.home()/'.ssh/pocket-test-accounts.json'
    if account_file.is_file():
        for account in read(account_file).get('accounts',[]):
            if account.get('password'):secret_audit.KNOWN.extend([account['password'].encode(),account['password'].encode('utf-16le')])
    apk=ROOT/'app/build/outputs/apk/release/app-release.apk'
    sdk=pathlib.Path(os.environ.get('ANDROID_HOME',str(pathlib.Path.home()/'AppData/Local/Android/Sdk')))/'build-tools/35.0.1'
    env={**os.environ,'JAVA_HOME':os.environ.get('JAVA_HOME','C:/Program Files/Android/Android Studio/jbr')}
    signature=subprocess.check_output([str(sdk/'apksigner.bat'),'verify','--verbose','--print-certs',str(apk)],env=env,text=True)
    badging=subprocess.check_output([str(sdk/'aapt.exe'),'dump','badging',str(apk)],text=True,encoding='utf-8')
    assert re.search(r'certificate SHA-256 digest: ([a-f0-9]+)',signature)[1]==CERT
    assert f"name='com.teno.app' versionCode='{code}' versionName='{version}'" in badging
    assert 'application-debuggable' not in badging and 'Verified using v2 scheme (APK Signature Scheme v2): true' in signature
    installed=read(qa/'final-install-report.json');native=read(qa/'full-runtime-report.json');regression=read(qa/'regression-runtime-report.json')
    assert installed['all_passed'] and not installed['uninstalled'] and installed['apk_sha256']==sha(apk)
    assert native['all_passed'] and regression['all_passed'] and regression['apk_sha256']==sha(apk)
    for report in (native,regression):assert all(v['passed'] for v in report['checks'])
    log=(qa/'android-checks.log').read_text(encoding='utf-8',errors='replace')
    assert 'All tests passed!' in log and 'No issues found!' in log
    total=int(re.search(r'\+(\d+):[^\n]*All tests passed!',log)[1])
    backend=read(qa/'backend-acceptance.json');assert backend['all_passed'] and re.fullmatch(r'\d+\.\d+\.\d+', backend['deployed_version'])
    assert backend['android_version']==version, 'Backend evidence must belong to this Android release'
    ui=read(ROOT/f'design-baseline/v{version}/pages.json');assert ui and all(len(v['variants'])==3 for v in ui)
    issues=ET.parse(ROOT/'app/build/reports/lint-results-release.xml').getroot().findall('issue')
    errors=sum(v.get('severity') in ('Error','Fatal') for v in issues);warnings=sum(v.get('severity')=='Warning' for v in issues);assert errors==0
    dist=ROOT/'dist';dist.mkdir(exist_ok=True)
    files=sorted(set(v.decode() for v in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).split(b'\0') if v))
    assert f'RELEASE-{version}.txt' in files, 'Track the versioned release notes before packaging'
    assert f'design-baseline/v{version}/differences-and-acceptance.txt' in files, 'Track the review acceptance notes before packaging'
    archive=dist/f'Teno-{version}-source.zip'
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as bundle:
        for name in files:
            path=ROOT/name;assert path.is_file() and not secret_audit.PRIVATE.search(name)
            assert path.suffix.lower() not in ('.apk','.ipa','.zip','.wav','.m4a','.mp3','.log','.db','.pem','.jks')
            bundle.write(path,f'Teno-{version}/'+name)
    for artifact in (apk,archive):secret_audit.archive(artifact.name,artifact.read_bytes())
    with zipfile.ZipFile(apk) as bundle:
        assert not any(name.endswith('jwd-synthetic-opus.bin') for name in bundle.namelist()), 'Synthetic test audio entered the application APK'
        for name in bundle.namelist():
            if name.endswith(('.dex','.so')):
                assert not any(v in bundle.read(name) for v in (b'RuntimeInstrumentation',b'JwdRuntimeChecks',b'FixtureHost',b'CoreHost',b'teno-cross-platform-fixture'))
    assert not secret_audit.FINDINGS,sorted((path,rule) for path,rule in secret_audit.FINDINGS)
    deliverable=dist/f'Teno-{version}.apk';shutil.copyfile(apk,deliverable)
    manifest={'application':'Teno','platform':'android','version':version,'version_code':code,'package':'com.teno.app',
        'packaged_at':datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat(),
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'apk':deliverable.name,'sha256':sha(deliverable),'bytes':deliverable.stat().st_size,
        'source_zip':archive.name,'source_zip_sha256':sha(archive),'source_files':len(files),
        'signer_sha256':CERT,'same_signer_as_previous_release':True,'debuggable':False,'apk_signature_v2_verified':True,
        'minimum_android_api':26,'target_android_api':35,'tested_android_api':35,
        'release_upgrade_install_and_cold_launch_passed':True,'upgraded_from':installed['original_upgrade_from'],
        'upgrade_runtime_checks':len(native['checks']),'upgrade_candidate_apk_sha256':native.get('upgrade_candidate_apk_sha256'),
        'regression_runtime_checks':len(regression['checks']),'flutter_tests':total,'ui_states':len(ui),'ui_screenshots':sum(len(v['variants']) for v in ui),
        'backend_version':backend['deployed_version'],'backend_tests':backend['isolated_tests'],'real_provider_checks':backend['real_provider_checks'],
        'lint_errors':errors,'lint_warnings':warnings,'speech_language':'auto','backend_modified':backend.get('backend_modified',True),'real_azure_retested':backend.get('real_provider_checks',0)>0,
        'physical_android_tested':False,'physical_jwd_tested':False,'near_120_min_provider_call_tested':False,
        'no_test_runners_in_apk':True,'private_credential_scan_passed':True,'ios':None,'baseline_promoted':False,
        'review':f'../design-baseline/v{version}/index.html','validation':f'../RELEASE-{version}.txt'}
    for name in ('release-manifest.json',f'Teno-{version}-release-manifest.json'):(dist/name).write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    (qa/'release-signature.txt').write_text(signature,encoding='utf-8');(qa/'release-badging.txt').write_text(badging,encoding='utf-8')
    (dist/'SHA256SUMS.txt').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in sorted(dist.iterdir()) if p.suffix in ('.apk','.ipa','.zip')),encoding='utf-8')
    print(json.dumps({'status':'pass','version':version,'apk_sha256':sha(deliverable),'flutter_tests':total,'lint_errors':errors,'lint_warnings':warnings}))
    credential=pathlib.Path.home()/'.ssh/teno-development-local.json'
    if credential.is_file() or os.environ.get('TENO_DEVELOPMENT_TOKEN'):
        from publish_development_release import normalize
        from report_development import configuration,send
        for envelope in normalize(dist/f'Teno-{version}-release-manifest.json',pathlib.Path.home()/'.teno/development-releases'):
            send(envelope,configuration(credential if credential.is_file() else None),pathlib.Path.home()/'.teno/development-outbox')
    return 0
