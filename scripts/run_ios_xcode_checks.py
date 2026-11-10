"""Bounded Xcode checks against the extracted recipient package; no signing credentials."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PROJECT = '/tmp/teno-xcode-relocated/Teno-iOS-0.7.1-Xcode/ios/Teno.xcodeproj'
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
        and (15,0) <= tuple(map(int,r['version'].split('.'))) <= (18,5)]
    if not supported:
        raise RuntimeError('Install an iOS15–18.5 Simulator runtime for the pinned Xcode16.4; inventory saved.')
    runtime = max(supported,key=lambda r:tuple(map(int,r['version'].split('.'))))
    selected = next((d['udid'] for d in devices['devices'].get(runtime['identifier'],[]) if d['name'].startswith('iPhone')),None)
    if not selected:
        selected = subprocess.check_output(['xcrun','simctl','create','Teno071CI','com.apple.CoreSimulator.SimDeviceType.iPhone-16',runtime['identifier']],text=True).strip()
    (BUILD/'simulator-selection.json').write_text(json.dumps({'udid':selected,'runtime':runtime['version'],'xcode':'16.4'}))
    print('Selected iOS Simulator:',runtime['version'],selected,flush=True)
    subprocess.run(['xcrun','simctl','boot',selected],capture_output=True,timeout=60)
    run(['xcrun','simctl','bootstatus',selected,'-b'],'ios-boot.log',180)
    args = xcode('Debug','platform=iOS Simulator,id='+selected)
    run(args+['build-for-testing'],'ios-build.log',600)
    run(['codesign','-d','--entitlements',':-',str(ROOT/'ios/DerivedData/Build/Products/Debug-iphonesimulator/Teno.app')],'ios-simulator-signing.log',30)
    run(args+['-parallel-testing-enabled','NO','-maximum-concurrent-test-simulator-destinations','1',
        '-test-timeouts-enabled','YES','-default-test-execution-time-allowance','45',
        '-maximum-test-execution-time-allowance','90','-resultBundlePath',str(BUILD/'TestResults.xcresult'),
        'test-without-building'],'ios-tests.log',600)
    run(['xcrun','simctl','install',selected,str(ROOT/'ios/DerivedData/Build/Products/Debug-iphonesimulator/Teno.app')],'ios-install.log',120)
    run(['xcrun','simctl','launch',selected,'com.teno.app'],'ios-launch.log',90)
    (BUILD/'screenshots').mkdir(exist_ok=True)
    run(['swift','scripts/capture_ios.swift',selected,str(BUILD/'screenshots/01-login.png')],'ios-capture.log',120)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('mode',choices=['device','simulator']); mode=parser.parse_args().mode
    if mode == 'device': run(xcode('Release','generic/platform=iOS')+['build'],'ios-release.log',600)
    else: simulator()
