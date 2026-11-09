"""Load only the unprefixed fonts used by the shared theme; native TTF stays in the APK."""
import json
from pathlib import Path

def prepare(build):
    path=Path(build)/'assets/FontManifest.json'
    rows=json.loads(path.read_text(encoding='utf-8'))
    fonts={row['family']:row['fonts'] for row in rows}
    # Product widgets use Inter/NotoSansSC without the optional package prefix.
    # Flutter otherwise eagerly downloads the redundant native TTF as well.
    assert all(name in fonts for name in ('Inter','NotoSansSC'))
    rows=[row for row in rows if row['family'] not in ('packages/teno_mobile/Inter','packages/teno_mobile/NotoSansSC')]
    assert all((Path(build)/'assets'/f['asset']).is_file() for row in rows for f in row['fonts'])
    path.write_text(json.dumps(rows,separators=(',',':'))+'\n',encoding='utf-8')
    return len(rows)

if __name__=='__main__':
    print('Prepared',prepare(Path(__file__).resolve().parents[1]/'web-client/build/web'),'local font families')
