"""Prepare immutable, same-origin Web assets; native files and APKs are untouched."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import re


def group_deferred_pages(build):
    """Coalesce Dart's tiny shared fragments without changing its load/initialization graph.

    Dart still validates every compiled fragment hash. Files shared by several
    routes transfer once; each route's exclusive code waits for that route.
    """
    code = (build/'main.dart.js').read_text(encoding='utf-8')
    libraries = re.search(r'deferredLibraryParts:\{([^\n]+)\},', code)
    uris = re.search(r'deferredPartUris:(\[[^\n]+\]),', code)
    if not libraries or not uris:
        assert not list(build.glob('main.dart.js_*.part.js')), 'Pinned Dart split metadata changed'
        return []
    paths = json.loads(uris[1])
    groups = re.findall(r'(?:"[^"]+"|[\w.]+):\[([\d,]*)\]', libraries[1])
    membership = {i: [] for i in range(len(paths))}
    for n, values in enumerate(groups):
        for i in map(int, values.split(',')):
            membership[i].append(n)
    bundles = {}
    for i, owners in membership.items():
        assert owners, paths[i]
        name = 'pages-shared.part.js' if len(owners)>1 else f'pages-route-{owners[0]:02d}.part.js'
        bundles.setdefault(name, []).append(paths[i])
    mapping = {}
    for name, files in bundles.items():
        assert all(re.fullmatch(r'main\.dart\.js_\d+\.part\.js', f) for f in files)
        (build/name).write_bytes(b'\n;\n'.join((build/f).read_bytes() for f in files)+b'\n')
        mapping.update({f:name for f in files})
    manifest = build/'page-bundles.json'
    manifest.write_text(json.dumps({'parts':mapping, 'bundles':bundles}, separators=(',', ':'))+'\n', encoding='utf-8')
    return [manifest, *(build/name for name in bundles)]


def bundle_assets(build):
    build = Path(build).resolve()
    marker = build/'startup-assets.json'
    if not (build/'main.dart.js').is_file():
        data = json.loads(marker.read_text(encoding='utf-8'))
        assert (build/data['base']/'main.dart.js').is_file()
        return data
    # These are generated Flutter files, not the gallery or application data.
    sources = [build/'main.dart.js', *sorted(build.glob('main.dart.js_*.part.js')), *group_deferred_pages(build)]
    proof = build/'asset-proof.json'
    proof.write_text(json.dumps({'main': hashlib.sha256((build/'main.dart.js').read_bytes()).hexdigest()})+'\n', encoding='utf-8')
    sources.append(proof)
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
    # The delivery selector preloads only its selected source; never download the
    # origin entrypoint in parallel with a CDN copy.
    text = text.replace('<meta name="teno-main-sha" content="">', '<meta name="teno-main-sha" content="'+files['main.dart.js']+'">')
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
    referenced = {f['asset'] for row in rows for f in row['fonts']}
    for family in ('packages/teno_mobile/Inter', 'packages/teno_mobile/NotoSansSC'):
        for font in fonts.get(family, []):
            if font['asset'] not in referenced:
                unused = (build/'assets'/font['asset']).resolve()
                assert unused.is_relative_to(build.resolve())
                unused.unlink(missing_ok=True)
    # This pipeline builds Dart JS with CanvasKit, not dart2wasm. Flutter copies
    # several unused alternative engines/debug symbol files into every release.
    for unused in (build/'canvaskit').rglob('*'):
        if unused.is_file() and (unused.suffix == '.symbols' or unused.name.startswith(('skwasm', 'wimp'))):
            assert unused.resolve().is_relative_to(build.resolve())
            unused.unlink()
    return bundle_assets(build)


def release_files(build):
    """Packaging includes the current bundle; older retained build caches stay out."""
    build = Path(build)
    active = json.loads((build/'startup-assets.json').read_text())['base']
    return [p for p in sorted(build.rglob('*')) if p.is_file()
            and (not p.relative_to(build).as_posix().startswith('_static/')
                 or p.relative_to(build).as_posix().startswith(active))]

if __name__=='__main__':
    build = Path(__file__).resolve().parents[1]/'web-client/build/web'
    data = prepare(build)
    print('Prepared immutable assets:', data['base'])
    subprocess.run(['node', str(Path(__file__).with_name('compress_web_assets.cjs')), str(build)], check=True)
