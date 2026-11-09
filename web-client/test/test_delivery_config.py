import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('delivery_config',ROOT/'scripts/configure_web_delivery.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)


class DeliveryConfig(unittest.TestCase):
    def test_only_static_csp_origins_are_added(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);(root/'deploy').mkdir()
            (root/'index.html').write_text('<meta name="teno-cdn" content=""><meta name="teno-main-sha" content="abc">')
            (root/'deploy/Caddyfile').write_text((ROOT/'web-client/deploy/Caddyfile').read_text())
            module.configure(root,['https://cdn.example/exact-commit/bundle/'])
            csp=(root/'deploy/Caddyfile').read_text()
            self.assertIn("script-src 'self' https://cdn.example 'wasm-unsafe-eval'",csp)
            self.assertIn("connect-src 'self' https://cdn.example;",csp)
            self.assertIn("form-action 'self';",csp)
            self.assertNotIn("script-src *",csp)
    def test_untrusted_configuration_cannot_inject_csp_or_credentials(self):
        for base in ['http://cdn.example/','https://user:password@cdn.example/','https://cdn.example/?data=private',"https://cdn.example/';script-src */"]:
            with self.assertRaises(ValueError):module.configure(Path('not-used'),[base])


if __name__=='__main__':unittest.main()
