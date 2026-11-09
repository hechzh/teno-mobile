"""Package a committed Web build separately from every Android release."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import zipfile
import sys

root = Path(__file__).resolve().parents[1]
repo = root.parent
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, default=repo/'dist')
parser.add_argument('--cdn-base', action='append', default=[])
args = parser.parse_args()
version, build_number = re.search(r'^version:\s*([^+\s]+)\+(\d+)', (root/'pubspec.yaml').read_text(), re.M).groups()
commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
assert not subprocess.check_output(['git', 'status', '--porcelain', '--', 'shared-ui', 'web-client'], cwd=repo), 'Commit Web sources before packaging'
build = root/'build/web'
assert (build/'main.dart.js').is_file() or (build/'startup-assets.json').is_file(), 'Run flutter build web first'
sys.path.insert(0,str(repo/'scripts'))
from prepare_web_assets import prepare, release_files
prepare(build)
shutil.copytree(root/'deploy', build/'deploy', dirs_exist_ok=True)
from configure_web_delivery import configure
configure(build, args.cdn_base)
subprocess.run(['node', str(repo/'scripts/compress_web_assets.cjs'), str(build)], check=True)
files = {p.relative_to(build).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
         for p in release_files(build) if p.name != 'release.json'}
manifest = {'version': version, 'build_number': int(build_number), 'source_commit': commit, 'app_ui_base': re.search(r"versionName '([^']+)'", (repo/'app/build.gradle').read_text(encoding='utf-8'))[1],
            'backend_minimum': '1.4.2', 'files': files}
(build/'release.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')
args.output.mkdir(parents=True, exist_ok=True)
prefix = 'Teno-Web-'+version
artifacts = []
with zipfile.ZipFile(args.output/(prefix+'.zip'), 'w', zipfile.ZIP_DEFLATED) as archive:
    for path in release_files(build):
        if path.is_file(): archive.write(path, path.relative_to(build).as_posix())
artifacts.append(args.output/(prefix+'.zip'))
with tarfile.open(args.output/(prefix+'.tar.gz'), 'w:gz') as archive:
    for path in release_files(build):
        if path.is_file(): archive.add(path, arcname=path.relative_to(build).as_posix())
artifacts.append(args.output/(prefix+'.tar.gz'))
source = args.output/(prefix+'-source.zip')
subprocess.run(['git', 'archive', '--format=zip', '--output='+str(source), 'HEAD',
                'web-client', 'shared-ui', '.github/workflows/web.yml',
                '.gitattributes', 'scripts/secret_audit.py', 'scripts/prepare_web_assets.py',
                'scripts/compress_web_assets.cjs', 'scripts/subset_web_fonts.py',
                'scripts/configure_web_delivery.py', 'scripts/publish_web_assets.py'], cwd=repo, check=True)
artifacts.append(source)
hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in artifacts}
(args.output/(prefix+'-manifest.json')).write_text(json.dumps({**manifest, 'artifacts': hashes}, indent=2)+'\n', encoding='utf-8')
(args.output/(prefix+'-SHA256SUMS.txt')).write_text(''.join(v+'  '+k+'\n' for k,v in hashes.items()), encoding='utf-8')
print(json.dumps({'version': version, 'commit': commit, 'artifacts': hashes}, indent=2))
