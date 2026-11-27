"""Build and package Web from the same committed source as the Android UI."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
from tempfile import TemporaryDirectory
import zipfile
import sys

root = Path(__file__).resolve().parents[1]
repo = root.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=repo/'dist')
parser.add_argument('--cdn-base', action='append', default=[])
parser.add_argument('--base-href', choices=['/app/', '/app-preview/'], default='/app/')
parser.add_argument('--flutter', default=shutil.which('flutter'))
parser.add_argument('--gallery', type=Path)
args = parser.parse_args()
if not args.flutter:
    parser.error('Flutter was not found on PATH. Pass --flutter.')
version, build_number = re.search(r'^version:\s*([^+\s]+)\+(\d+)', (root/'pubspec.yaml').read_text(), re.M).groups()
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
sys.path.insert(0,str(repo/'scripts'))
from prepare_web_assets import prepare, release_files
from configure_web_delivery import configure

status_command = ['git', 'status', '--porcelain', '--', 'app/build.gradle', 'shared-ui', 'web-client']
assert not subprocess.check_output(status_command, cwd=repo), 'Commit Android and Web sources before packaging'
android = (repo/'app/build.gradle').read_text(encoding='utf-8')
app_ui_base = re.search(r"versionName '([^']+)'", android)[1]
app_ui_build = int(re.search(r'versionCode\s+(\d+)', android)[1])
prefix = 'Teno-Web-'+version
zip_path = args.output/(prefix+'.zip')
tar_path = args.output/(prefix+'.tar.gz')
with TemporaryDirectory(prefix='teno-web-release-') as directory:
    build = Path(directory) / 'web'
    subprocess.run([args.flutter, 'pub', 'get', '--enforce-lockfile'], cwd=root, check=True)
    subprocess.run([
        args.flutter, 'build', 'web', '--release', '--no-pub', '--no-web-resources-cdn',
        '--base-href', args.base_href, '--output', str(build),
    ], cwd=root, check=True)
    assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip() == commit
    assert not subprocess.check_output(status_command, cwd=repo), 'Android or Web source changed during the build'
    if args.gallery:
        gallery = args.gallery
        for image in json.loads((gallery/'screenshot-manifest.json').read_text(encoding='utf-8')):
            screenshot = (gallery/image['screenshot']).resolve()
            assert screenshot.is_relative_to(gallery.resolve()), image['screenshot']
            assert hashlib.sha256(screenshot.read_bytes()).hexdigest() == image['sha256'], image['screenshot']
        shutil.copytree(gallery, build/'ui-review')

    prepare(build)
    shutil.copytree(root/'deploy', build/'deploy', dirs_exist_ok=True)
    configure(build, args.cdn_base)
    subprocess.run(['node', str(repo/'scripts/compress_web_assets.cjs'), str(build)], check=True)
    files = {p.relative_to(build).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in release_files(build)}
    manifest = {
        'version': version, 'build_number': int(build_number), 'source_commit': commit,
        'app_ui_base': app_ui_base, 'app_ui_build': app_ui_build, 'base_href': args.base_href,
        'backend_minimum': '1.8.0', 'files': files,
    }
    (build/'release.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
    args.output.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as archive, tarfile.open(tar_path, 'w:gz') as tar:
        for path in release_files(build):
            name = path.relative_to(build).as_posix()
            archive.write(path, name)
            tar.add(path, arcname=name)
artifacts = [zip_path, tar_path]
source = args.output/(prefix+'-source.zip')
subprocess.run(['git', 'archive', '--format=zip', '--output='+str(source), commit,
                'web-client', 'shared-ui', 'app/build.gradle', '.github/workflows/web.yml',
                '.gitattributes', 'scripts/secret_audit.py', 'scripts/prepare_web_assets.py',
                'scripts/compress_web_assets.cjs', 'scripts/subset_web_fonts.py',
                'scripts/configure_web_delivery.py', 'scripts/publish_web_assets.py'], cwd=repo, check=True)
artifacts.append(source)
hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in artifacts}
(args.output/(prefix+'-manifest.json')).write_text(json.dumps({**manifest, 'artifacts': hashes}, indent=2)+'\n', encoding='utf-8')
(args.output/(prefix+'-SHA256SUMS.txt')).write_text(''.join(v+'  '+k+'\n' for k,v in hashes.items()), encoding='utf-8')
print(json.dumps({'version': version, 'commit': commit, 'artifacts': hashes}, indent=2))
