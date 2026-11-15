import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT/'web-client/assets/fonts/subsets'


class FontPartitions(unittest.TestCase):
    def test_complete_manifest_has_disjoint_hashed_files_and_small_startup_font(self):
        manifest = json.loads((FONTS/'manifest.json').read_text(encoding='utf-8'))
        self.assertLess(manifest['initial']['bytes'], 150_000)
        self.assertEqual(manifest['source_sha256'], hashlib.sha256((FONTS.parent/'NotoSansSC-Regular.woff2').read_bytes()).hexdigest())
        seen = set()
        families = set()
        for chunk in [manifest['initial'], *manifest['chunks']]:
            points = set(chunk['chars'])
            self.assertFalse(seen & points)
            seen.update(points)
            self.assertEqual(hashlib.sha256((FONTS/chunk['file']).read_bytes()).hexdigest(), chunk['sha256'])
            if 'family' in chunk:
                self.assertNotIn(chunk['family'], families)
                families.add(chunk['family'])
                self.assertIn("'"+chunk['family']+"'", (ROOT/'shared-ui/lib/ui/font_families_web.dart').read_text())
        self.assertGreater(len(seen), 29_000)
        self.assertTrue(set('中文上海生僻龘𠮷') - {'𠮷'} <= seen)

    def test_web_manifest_does_not_eagerly_request_the_full_cjk_font(self):
        pubspec = (ROOT/'web-client/pubspec.yaml').read_text()
        self.assertIn('asset: assets/fonts/subsets/ui.woff2', pubspec)
        self.assertNotIn('asset: assets/fonts/NotoSansSC-Regular.woff2', pubspec)
        self.assertIn('assets/fonts/NotoSansSC-Regular.ttf', (ROOT/'shared-ui/pubspec.yaml').read_text())

    def test_authored_ui_glyphs_need_no_content_download(self):
        manifest = json.loads((FONTS/'manifest.json').read_text(encoding='utf-8'))
        initial = set(manifest['initial']['chars'])
        supported = initial | set(''.join(chunk['chars'] for chunk in manifest['chunks']))
        # Loading/error labels render before dynamic content fonts can load.
        # Catch new authored characters that were added after font generation.
        for folder in ['shared-ui/lib', 'web-client/lib']:
            for file in (ROOT/folder).rglob('*.dart'):
                missing = (set(file.read_text(encoding='utf-8')) & supported) - initial
                self.assertFalse(missing, f'{file.relative_to(ROOT)}: regenerate UI font for {missing}')


if __name__ == '__main__': unittest.main()
