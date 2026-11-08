"""Create a versioned review with explicit, independently reviewed references."""
import argparse, hashlib, html, json, re, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--version');p.add_argument('--references',type=Path,default=ROOT.parent/'design-review/plaud-rebuild/20261104');a=p.parse_args()
version=a.version or re.search(r"versionName\s+['\"]([^'\"]+)",(ROOT/'app/build.gradle').read_text(encoding='utf-8'))[1]
assert re.fullmatch(r'\d+\.\d+\.\d+',version)
out=ROOT/f'design-baseline/v{version}'
def read(path):return json.loads(path.read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def esc(value):return html.escape(str(value),quote=True)
mapping=read(out/'reference-map.json')
images={im['file']:{**im,'article':s['url']} for s in read(a.references/'evidence/sources.json') for im in s.get('images',[])}
labels={'same':'同页同状态','related':'相关页面参考','missing':'缺少原图'}
css='''*{box-sizing:border-box}body{font:15px/1.65 system-ui;background:#f6f7f8;color:#20242a;margin:0}main{max-width:1180px;margin:auto;padding:24px}h1{font-size:25px}nav,.controls{display:flex;gap:12px;flex-wrap:wrap}a{color:#2462a0}article{border:1px solid #dde1e5;border-radius:12px;padding:18px;background:white;margin:18px 0}button,select,input{font:inherit;padding:8px 12px;border:1px solid #c9cdd1;border-radius:8px;background:white}button{cursor:pointer}.muted{color:#60666e}.screens{display:flex;gap:20px;overflow:auto;padding:16px 0;align-items:flex-start}.screens figure{margin:0;flex:0 0 390px}.screens img{width:390px;height:auto;border:1px solid #ddd;display:block}.screens figcaption{margin-bottom:8px}li{margin:8px 0}.badge{font-size:12px;padding:3px 8px;background:#e9edf1;border-radius:5px}'''
def document(title,body):return f'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{esc(title)}</title><style>{css}</style><main>{body}</main></html>'
(out/'pages').mkdir(exist_ok=True);(out/'references').mkdir(exist_ok=True)
records=[]
for i,row in enumerate(mapping):
    key=row['id'];variants=[];official=[]
    for mode in ('light','dark','large'):
        file=out/'screenshots/android'/mode/(key+'.png');assert file.is_file(),file
        variants.append({'name':mode,'screenshot':file.relative_to(out).as_posix(),'sha256':sha(file)})
    for name in row['refs']:
        original=a.references/'evidence'/name;assert original.is_file(),original
        destination=out/'references'/name;shutil.copyfile(original,destination)
        official.append({**images[name],'local_path':destination.relative_to(out).as_posix(),'sha256':sha(original)})
    record={**row,'reference_classification':labels[row['category']],'inferred_state':row['category']!='same','variants':variants,'official_sources':official,
      'evidence':'Current Flutter code with synthetic data; application navigation from Home, signed-out Login. Physical devices remain unverified.'}
    records.append(record)
    prev=mapping[i-1]['id'];nxt=mapping[(i+1)%len(mapping)]['id']
    options=''.join(f'<option value="../{esc(v["local_path"])}">{esc(v["file"])}</option>' for v in official)
    compare=f'<figure id="reference"><figcaption>PLAUD 4.x · {esc(labels[row["category"]])}</figcaption><img id="original" src="../{official[0]["local_path"]}"></figure>' if official else ''
    citations=' · '.join(f'<a href="{esc(v["article"])}">{esc(v["file"])} 官方文档</a>' for v in official)
    differences='；'.join(row.get('retained_differences',[])) or 'Teno / Ask Teno 品牌、样例数据及 Android 系统行为按本项目保留。'
    body=f'''<nav><a href="../index.html">全部状态</a><a href="{prev}.html">上一状态</a><a href="{nxt}.html">下一状态</a></nav><h1>{esc(key)} · {esc(row['title'])}</h1><article><b>{esc(labels[row['category']])}</b><p>{esc(row['reason'])}</p><p>{esc(row['change'])}</p><p>保留差异：{esc(differences)}</p><p>视觉记录：{esc(row['visual_status'])}</p><small class="muted">{citations}。官方图含 iOS 系统栏，不是原版 APK 运行实录；当前截图使用合成资料。</small></article><div class="controls">{''.join(f'<button onclick="mode(\'{v["name"]}\')">{v["name"]}</button>' for v in variants)}<select onchange="document.querySelector('#original').src=this.value">{options}</select><label><input type="checkbox" checked onchange="document.querySelector('#reference')?.toggleAttribute('hidden',!this.checked)">显示同宽参考</label></div><div class="screens"><figure><figcaption id="label">Teno {version} · light</figcaption><img id="current" src="../{variants[0]['screenshot']}"></figure>{compare}</div><p class="muted">正常截图按 390dp 等显示宽度比较；large 原布局宽 360dp／1.5 倍字体。系统栏、教学蓝框和样例资料不纳入几何结论。相关/缺图状态不称已还原。</p><script>function mode(m){{document.querySelector('#current').src='../screenshots/android/'+m+'/{key}.png';document.querySelector('#label').textContent='Teno {version} · '+m}}</script>'''
    (out/'pages'/(key+'.html')).write_text(document(f'Teno {version} · '+row['title'],body),encoding='utf-8')
(out/'pages.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
native=read(out/'native-pages.json') if (out/'native-pages.json').exists() else []
native_html='<ul>'+''.join(f'<li><a href="{esc(v["path"])}">{esc(v["id"])}</a></li>' for v in native)+'</ul>' if native else '<p>原生系统截图尚未生成。</p>'
counts={label:sum(v['category']==key for v in records) for key,label in labels.items()}
body=f'''<h1>Teno Android {version} · 逐页对照与验收</h1><article><p>{len(records)} 个独立状态，浅色／深色／360dp 与 1.5 倍字号，共 {len(records)*3} 张测试截图。</p><p>{esc('；'.join(k+' '+str(v) for k,v in counts.items()))}。参考分类与视觉验收分开，缺图明确推定。</p><nav><a href="differences-and-acceptance.txt">已对齐、差异、推定与待实机清单</a><a href="measurements.html">六个基准页面的几何校准</a><a href="../../RELEASE-{version}.txt">版本验证与安装</a><a href="../v0.6.0/index.html">保留的 0.6.0 证据</a></nav></article><article><b>本轮 Android 模拟器系统画面</b>{native_html}<p class="muted">真实 API35 模拟器截图；不等于 Magic4 Pro / JWD 硬件验收。</p></article><input type="search" placeholder="查找页面或状态" oninput="for(const li of document.querySelectorAll('li[data-key]'))li.hidden=!li.textContent.toLowerCase().includes(this.value.toLowerCase())"><ol>{''.join(f'<li data-key="{r["id"]}"><a href="pages/{r["id"]}.html">{r["id"]} · {esc(r["title"])}</a> <span class="badge">{esc(r["reference_classification"])}</span></li>' for r in records)}</ol>'''
(out/'index.html').write_text(document(f'Teno {version} · 逐页对照',body),encoding='utf-8')
print(json.dumps({'version':version,'states':len(records),'screenshots':len(records)*3,'reference_categories':counts},ensure_ascii=False))
