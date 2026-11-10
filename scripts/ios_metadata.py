"""Read iOS identity independently of the Android/shared UI release number."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def metadata():
    source = (ROOT/'ios/project.yml').read_text(encoding='utf-8')
    app = source.split('  Teno:\n',1)[1].split('  TenoTests:\n',1)[0]
    def value(key):
        return re.search(r'^\s*'+key+r':\s*[\'"]?([^\'"\s]+)',app,re.M)[1]
    version=value('CFBundleShortVersionString'); build=value('CFBundleVersion'); bundle=value('PRODUCT_BUNDLE_IDENTIFIER')
    assert value('MARKETING_VERSION') == version
    assert value('CURRENT_PROJECT_VERSION') == build
    assert re.fullmatch(r'\d+\.\d+(?:\.\d+)?',version)
    assert re.fullmatch(r'[1-9]\d*',build)
    assert re.fullmatch(r'[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+',bundle)
    return {'version':version,'build':build,'bundle_id':bundle,
        'source_name':f'Teno-iOS-{version}-build{build}-Xcode',
        'ipa_name':f'Teno-iOS-{version}-build{build}-unsigned.ipa'}


if __name__ == '__main__':
    for key,value in metadata().items():print(key+'='+value)
