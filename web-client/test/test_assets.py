"""Asset identity is the contract that makes a year-long browser cache safe."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

script = Path(__file__).resolve().parents[2]/'scripts/prepare_web_assets.py'
spec = importlib.util.spec_from_file_location('prepare_web_assets', script)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Assets(unittest.TestCase):
    def create(self, root, main=b'first app'):
        rows = []
        for name in ('Inter', 'NotoSansSC', 'packages/teno_mobile/Inter', 'packages/teno_mobile/NotoSansSC'):
            asset = name+'.ttf'
            p = root/'assets'/asset
            p.parent.mkdir(parents=True,exist_ok=True)
            p.write_bytes(b'font')
            rows.append({'family':name,'fonts':[{'asset':asset}]})
        (root/'assets/FontManifest.json').write_text(json.dumps(rows))
        (root/'main.dart.js').write_bytes(main)
        (root/'index.html').write_text('<head><meta name="teno-assets" content="./"></head>')

    def test_stable_hash_and_idempotence(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.create(root);first=module.prepare(root)
            self.assertEqual(module.prepare(root),first)
            self.assertFalse((root/'main.dart.js').exists())
            for name,digest in first['files'].items():
                self.assertEqual(hashlib.sha256((root/first['base']/name).read_bytes()).hexdigest(),digest)
            families=[r['family'] for r in json.loads((root/first['base']/'assets/FontManifest.json').read_text())]
            self.assertEqual(families,['Inter','NotoSansSC'])
            self.assertIn(first['base']+'main.dart.js',(root/'index.html').read_text())

    def test_new_content_gets_a_new_path_and_old_content_is_retained(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);self.create(root);first=module.prepare(root)
            self.create(root,b'new app');second=module.prepare(root)
            self.assertNotEqual(first['base'],second['base'])
            self.assertEqual((root/first['base']/'main.dart.js').read_bytes(),b'first app')
            self.assertEqual((root/second['base']/'main.dart.js').read_bytes(),b'new app')

if __name__=='__main__':unittest.main()
