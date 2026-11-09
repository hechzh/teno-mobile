"""Prepare immutable, same-origin Web assets; native files and APKs are untouched."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def bundle_assets(build):
    build = Path(build).resolve()
    marker = build/'startup-assets.json'
    if not (build/'main.dart.js').is_file():
        data = json.loads(marker.read_text(encoding='utf-8'))
        assert (build/data['base']/'main.dart.js').is_file()
        return data
    # These are generated Flutter files, not the gallery or application data.
    sources = [build/'main.dart.js']
    for name in ('assets', 'canvaskit', 'shared-ui'):
        folder = build/name
        if folder.is_dir():
            sources.extend(p for p in folder.rglob('*') if p.is_file())
    files = {p.relative_to(build).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(sources)}
    digest = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()[:24]
    relative = '_static/'+digest+'/'
    target = build/relative
    for source in sources:
        destination = target/source.relative_to(build)
        assert source.resolve().is_relative_to(build) and destination.resolve().is_relative_to(build)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)
        # Remove only the verified generated file after the complete copy.
        assert hashlib.sha256(destination.read_bytes()).hexdigest() == files[source.relative_to(build).as_posix()]
        source.unlink()
    index = build/'index.html'
    text = index.read_text(encoding='utf-8')
    assert '<meta name="teno-assets" content="./">' in text, 'Build the new startup HTML first'
    text = text.replace('<meta name="teno-assets" content="./">', '<meta name="teno-assets" content="'+relative+'">')
    text = text.replace('</head>', '<link rel="preload" href="'+relative+'main.dart.js" as="script">\n</head>')
    index.write_text(text, encoding='utf-8')
    data = {'base': relative, 'files': files}
    marker.write_text(json.dumps(data, indent=2)+'\n', encoding='utf-8')
    return data

def prepare(build):
    build = Path(build)
    if not (build/'main.dart.js').is_file() and (build/'startup-assets.json').is_file():
        return bundle_assets(build)
    path=Path(build)/'assets/FontManifest.json'
    rows=json.loads(path.read_text(encoding='utf-8'))
    fonts={row['family']:row['fonts'] for row in rows}
    # Product widgets use Inter/NotoSansSC without the optional package prefix.
    # Flutter otherwise eagerly downloads the redundant native TTF as well.
    assert all(name in fonts for name in ('Inter','NotoSansSC'))
    rows=[row for row in rows if row['family'] not in ('packages/teno_mobile/Inter','packages/teno_mobile/NotoSansSC')]
    assert all((Path(build)/'assets'/f['asset']).is_file() for row in rows for f in row['fonts'])
    path.write_text(json.dumps(rows,separators=(',',':'))+'\n',encoding='utf-8')
    return bundle_assets(build)

if __name__=='__main__':
    build = Path(__file__).resolve().parents[1]/'web-client/build/web'
    data = prepare(build)
    print('Prepared immutable assets:', data['base'])
    subprocess.run(['node', str(Path(__file__).with_name('compress_web_assets.cjs')), str(build)], check=True)
