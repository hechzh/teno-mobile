"""Bounded Xcode checks against the extracted recipient package; no signing credentials."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time
from ios_metadata import metadata as ios_metadata

ROOT = Path(__file__).resolve().parents[1]
IDENTITY = ios_metadata()
PROJECT = str(Path('/tmp/teno-xcode-relocated')/IDENTITY['source_name']/'ios/Teno.xcodeproj')
BUILD = ROOT / 'ios/build'


def run(args, log, timeout=600):
    path = ROOT / log
    with path.open('w') as stream:
        process = subprocess.Popen(args, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
            start_new_session=True, env={**os.environ, 'FLUTTER_ROOT':'/not-installed'})
        try:
            result = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGINT)
            try: process.wait(timeout=30)
            except subprocess.TimeoutExpired: os.killpg(process.pid,signal.SIGKILL); process.wait()
            print(f'Timed out after {timeout}s: {log}')
            result = 124
    if result:
        print('\n'.join(path.read_text(errors='replace').splitlines()[-100:]))
        raise SystemExit(result)


def xcode(configuration, destination):
    return ['xcodebuild','-project',PROJECT,'-scheme','Teno','-configuration',configuration,
        '-destination',destination,'-derivedDataPath',str(ROOT/'ios/DerivedData')]+(
        ['CODE_SIGNING_ALLOWED=YES','CODE_SIGN_IDENTITY=-'] if 'Simulator' in destination else ['CODE_SIGNING_ALLOWED=NO'])


def simulator():
    runtimes = json.loads(subprocess.check_output(['xcrun','simctl','list','runtimes','-j']))
    devices = json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))
    BUILD.mkdir(parents=True,exist_ok=True)
    (BUILD/'simulator-inventory.json').write_text(json.dumps({'runtimes':runtimes,'devices':devices},indent=2))
    supported = [r for r in runtimes['runtimes'] if r.get('isAvailable') and '.iOS-' in r['identifier']
        and tuple(map(int,r['version'].split('.'))) >= (15,0)]
    if not supported:
        raise RuntimeError('Install an iOS Simulator runtime for Xcode 26+ (iOS 26/27 recommended); inventory saved.')
    runtime = max(supported,key=lambda r:tuple(map(int,r['version'].split('.'))))
    selected = next((d['udid'] for d in devices['devices'].get(runtime['identifier'],[]) if d['name'].startswith('iPhone')),None)
    if not selected:
        # Device types from older Xcode releases are not always present in a
        # newer runtime; pick the newest iPhone type the host actually offers.
        types = json.loads(subprocess.check_output(['xcrun','simctl','list','devicetypes','-j']))['devicetypes']
        iphones = [t['identifier'] for t in types if t['name'].startswith('iPhone')]
        if not iphones:
            raise RuntimeError('No iPhone Simulator device type is installed.')
        def rank(identifier):
            numbers = re.findall(r'\d+', identifier)
            return tuple(map(int,numbers)) if numbers else (0,)
        device_type = max(iphones,key=rank)
        selected = subprocess.check_output(['xcrun','simctl','create','TenoCI',device_type,runtime['identifier']],text=True).strip()
    xcode_version = subprocess.check_output(['xcodebuild','-version'],text=True).strip()
    (BUILD/'simulator-selection.json').write_text(json.dumps({'udid':selected,'runtime':runtime['version'],'xcode':xcode_version}))
    print('Selected iOS Simulator:',runtime['version'],selected,flush=True)
    if not shutil.which('tesseract'):
        raise SystemExit('tesseract is required for the simulator screenshot check (brew install tesseract).')
    (BUILD/'screenshots').mkdir(parents=True,exist_ok=True)
    subprocess.run(['xcrun','simctl','boot',selected],capture_output=True,timeout=60)
    # Fresh hosted runtimes can spend more than three minutes migrating system
    # apps before our app is installed. Keep a separate bounded startup budget.
    run(['xcrun','simctl','bootstatus',selected,'-b'],'ios-boot.log',600)
    args = xcode('Debug','platform=iOS Simulator,id='+selected)
    run(args+['build-for-testing'],'ios-build.log',600)
    run(['codesign','-d','--entitlements',':-',str(ROOT/'ios/DerivedData/Build/Products/Debug-iphonesimulator/Teno.app')],'ios-simulator-signing.log',30)
    run(args+['-parallel-testing-enabled','NO','-maximum-concurrent-test-simulator-destinations','1',
        '-test-timeouts-enabled','YES','-default-test-execution-time-allowance','45',
        '-maximum-test-execution-time-allowance','90','-resultBundlePath',str(BUILD/'TestResults.xcresult'),
        'test-without-building'],'ios-tests.log',600)
    run(['xcrun','simctl','install',selected,str(ROOT/'ios/DerivedData/Build/Products/Debug-iphonesimulator/Teno.app')],'ios-install.log',120)
    subprocess.run(['xcrun','simctl','terminate',selected,IDENTITY['bundle_id']],capture_output=True,timeout=30)
    run(['xcrun','simctl','launch',selected,IDENTITY['bundle_id']],'ios-launch.log',90)
    capture_login_screen(selected)


def capture_login_screen(selected):
    """Capture the simulator and require the rendered Teno sign-in text.

    A successful ``simctl launch`` is not proof that Flutter painted its first
    frame. Vision OCR crashes on the Xcode 27 host, so the screenshot is read
    with the tesseract CLI instead of a compiled helper.
    """
    png = BUILD/'screenshots/01-login.png'; log = ROOT/'ios-capture.log'
    deadline = time.time() + 60; verified = False
    # Some Xcode 27 runners expose an extra virtual display, and simctl then
    # refuses a screenshot without an explicit display selector.
    displays = ([], ['--display=internal'], ['--display=1'], ['--display=3'])
    with log.open('w') as stream:
        while time.time() < deadline:
            for extra in displays:
                shot = subprocess.run(['xcrun','simctl','io',selected,'screenshot',*extra,str(png)],
                    capture_output=True, text=True)
                stream.write(shot.stdout + shot.stderr)
                if shot.returncode != 0 or not png.is_file():
                    continue
                ocr = subprocess.run(['tesseract',str(png),'stdout'],capture_output=True,text=True)
                stream.write(ocr.stdout + ocr.stderr)
                words = (ocr.stdout or '').lower()
                if 'teno' in words and ('sign in' in words or 'signin' in words):
                    verified = True; break
            if verified:
                break
            time.sleep(2)
    if not verified:
        print(log.read_text(errors='replace')[-2000:])
        raise SystemExit('Teno sign-in screen did not render within 60 seconds; inspect '+str(png))
    print('Teno sign-in screen verified from the native simulator screenshot.')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('mode',choices=['device','simulator']); mode=parser.parse_args().mode
    if mode == 'device': run(xcode('Release','generic/platform=iOS')+['build'],'ios-release.log',600)
    else: simulator()
