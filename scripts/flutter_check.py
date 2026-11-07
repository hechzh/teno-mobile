"""Run pinned Flutter checks without overwriting historical page evidence."""
import argparse, os, pathlib, subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument('action', choices=['analyze', 'test', 'personal-pages', 'release-checks'])
args = p.parse_args()
flutter = pathlib.Path(os.environ.get('FLUTTER_ROOT', str(pathlib.Path.home()/'AppData/Local/teno-tools/flutter'))) / 'bin' / ('flutter.bat' if os.name == 'nt' else 'flutter')
env = dict(os.environ)
env.pop('TENO_SCREENSHOTS', None)
if args.action in ('personal-pages', 'release-checks'):
    env['TENO_PERSONAL_SCREENSHOTS'] = str(ROOT/'design-baseline/v0.6.0/screenshots/android')
    if args.action == 'release-checks':
        analyzed = subprocess.run([str(flutter), 'analyze', '--no-pub'], cwd=ROOT/'shared-ui', env=env)
        if analyzed.returncode: raise SystemExit(analyzed.returncode)
        command = [str(flutter), 'test', '--no-pub', '--reporter', 'expanded']
    else: command = [str(flutter), 'test', '--no-pub', 'test/personal_test.dart', '--reporter', 'expanded']
else: command = [str(flutter), 'analyze', '--no-pub'] if args.action == 'analyze' else [str(flutter), 'test', '--no-pub', '--reporter', 'expanded']
raise SystemExit(subprocess.run(command, cwd=ROOT/'shared-ui', env=env).returncode)
