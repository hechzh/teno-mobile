"""Version-specific checks on an explicitly selected dedicated emulator only."""
import argparse, hashlib, json, os, pathlib, re, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(); p.add_argument('mode', choices=['upgrade','regression','final'])
p.add_argument('--device', default='emulator-5554'); p.add_argument('--baseline', default='0.5.0')
args = p.parse_args()
version = re.search(r"versionName '([^']+)'", (ROOT/'app/build.gradle').read_text())[1]
qa = ROOT/'verification'/('v'+version); qa.mkdir(parents=True, exist_ok=True)
adb = pathlib.Path(os.environ.get('ANDROID_HOME', str(pathlib.Path.home()/'AppData/Local/Android/Sdk')))/'platform-tools/adb.exe'
def run(*command): return subprocess.check_output([str(adb), '-s', args.device, *command], text=True, encoding='utf-8', errors='replace')
assert args.device.startswith('emulator-') and any(v in run('shell','getprop','ro.hardware') for v in ('ranchu','goldfish'))
apk = ROOT/'app/build/outputs/apk/release/app-release.apk'
metadata = json.loads(apk.with_name('output-metadata.json').read_text())
assert metadata['elements'][0]['versionName'] == version, 'Build the new release APK before starting verification'
package = 'com.teno.app'
external = '/sdcard/Android/data/'+package+'/files/'
def install(file):
    assert 'Success' in run('install','-r',str(file))
def instrument(mode):
    output = run('shell','am','instrument','-w','-e','mode',mode,'-e','baseline',args.baseline,
        package+'.test/com.teno.app.RuntimeInstrumentation')
    run('pull', external+mode+'-runtime-report.json', str(qa/(mode+'-runtime-report.json')))
    report = json.loads((qa/(mode+'-runtime-report.json')).read_text())
    assert report['all_passed'], report.get('failure',output)
    assert all(v['passed'] for v in report['checks'])
    if mode != 'seed':
        report['apk_sha256']=hashlib.sha256(apk.read_bytes()).hexdigest()
        (qa/(mode+'-runtime-report.json')).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps({'mode':mode,'passed':True,'checks':len(report['checks'])}))
if args.mode == 'upgrade':
    assert 'versionName='+args.baseline in run('shell','dumpsys','package',package), 'Seed requires the original baseline APK; never downgrade a user installation'
    install(ROOT/'app/build/outputs/apk/androidTest/release/app-release-androidTest.apk')
    instrument('seed'); install(apk); instrument('full')
    for name in ('01-home-upgrade','02-runtime-finished'): run('pull', external+name+'.png', str(qa/(name+'.png')))
elif args.mode == 'regression':
    instrument('regression')
    for name in ('03-import-entry-android','05-system-files-android','06-system-photos-android','07-system-keyboard-android'):
        run('pull', external+name+'.png', str(qa/(name+'.png')))
else:
    install(apk)
    assert 'versionName='+version in run('shell','dumpsys','package',package)
    run('shell','am','force-stop',package); run('logcat','-b','crash','-c')
    run('shell','am','start','-W','-n',package+'/com.teno.app.MainActivity'); time.sleep(5)
    assert run('shell','pidof',package).strip()
    assert 'FATAL EXCEPTION' not in run('logcat','-b','crash','-d')
    remote_screen=f'/sdcard/teno-{version}-cold-start.png'
    run('shell','screencap','-p',remote_screen)
    run('pull',remote_screen,str(qa/'04-final-login-android.png'))
    report={'all_passed':True,'device':args.device+' dedicated API35 emulator','apk_sha256':hashlib.sha256(apk.read_bytes()).hexdigest(),
        'package':package,'version':version,'uninstalled':False,'install_mode':'adb install -r','original_upgrade_from':args.baseline,
        'original_upgrade_evidence':'full-runtime-report.json','final_update_and_cold_launch':True,'crash_buffer_clean':True,
        'screenshot':'04-final-login-android.png','physical_device':False}
    (qa/'final-install-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('Signed release update and cold launch passed on dedicated emulator.')
