"""Share reviewed UI terms with native dialogs and foreground notifications."""
import json
from pathlib import Path
from xml.sax.saxutils import escape

root = Path(__file__).resolve().parents[1]
arb = root / 'shared-ui/lib/l10n'
source = json.loads((arb / 'app_en.arb').read_text(encoding='utf-8'))
keys = [k for k, v in source.items() if not k.startswith('@') and '{' not in v]
for lang, folder in [('en', 'values'), ('zh', 'values-zh-rCN')]:
    values = json.loads((arb / f'app_{lang}.arb').read_text(encoding='utf-8'))
    lines = ['<?xml version="1.0" encoding="utf-8"?>', '<!-- Generated from the reviewed shared ARB resources. -->', '<resources>']
    for key in keys:
        value = escape(values[key]).replace('\\', '\\\\').replace("'", "\\'").replace('"', '\\"').replace('\n', '\\n')
        lines.append(f'  <string name="ui_{key.lower()}" formatted="false">{value}</string>')
    lines.append('</resources>')
    path = root / f'app/src/main/res/{folder}/ui_labels.xml'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text('\n'.join(lines)+'\n', encoding='utf-8')
lines = ['package com.teno.app;', '// Generated from shared ARB. Do not edit.', 'final class UiLocaleLabels {', '  static int resource(String source) {', '    switch(source) {']
for key in keys:
    literal = json.dumps(source[key], ensure_ascii=False)
    lines.append(f'      case {literal}: return R.string.ui_{key.lower()};')
lines += ['      default: return 0;', '    }', '  }', '}']
(root / 'app/src/main/java/com/teno/app/UiLocaleLabels.java').write_text('\n'.join(lines)+'\n', encoding='utf-8')
print(f'Generated {len(keys)} native UI label resources in two languages.')
