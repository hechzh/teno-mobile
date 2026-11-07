"""Independent 0.6.0 pages, original-source links, changes and current captures."""
import hashlib,html,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'design-baseline/v0.6.0';REFERENCE=ROOT.parent/'design-review/plaud-rebuild/20261104'
references={p['id']:p for p in json.loads((REFERENCE/'page-manifest.json').read_text(encoding='utf-8'))}
sources=json.loads((REFERENCE/'evidence/sources.json').read_text(encoding='utf-8'))
images={im['file']:{**im,'article':source['url']} for source in sources for im in source.get('images',[])}
mapping={'01':'01','02':'02','03':'03','04':'04','05':'05','06':'06','07':'07','09':'09','10':'10',
    '14':'14','15':'15','17':'25','18':'18','19':'19','20':'31','21':'21','22':'22','23':'23','24':'24',
    '26':'26','27':'27','28':'28','29':'04','30':'32','31':'26','32':'32','33':'32','34':None,'35':'29','36':'29','37':'22','38':'27',
    '39':'01','40':'04','41':'04','42':'01','43':'06','44':'33','45':'33','46':'33','47':'33','48':'14',
    '49':'15','50':'16','51':None,'52':'15','53':'13','54':'14','55':'23','56':'28','57':None,'58':None,
    '59':'26','60':'26','61':'32','62':'30','63':'01','64':'27'}
changes={
 '01':'恢复 Upcoming、日期分组、排序入口和底部 Ask；本机未上传文件单独标明状态。',
 '02':'侧栏分组与选中样式对齐；品牌为 Teno / Ask Teno，本期不显示 Work、会员和团队。',
 '03':'新增菜单包含设备录音、导入和新 Chat；手机录音保留次级入口。',
 '04':'系统目录、嵌套文件夹、排序、批量移动/删除/恢复和拖拽归档。',
 '06':'解析旧 recording + matches 契约；新检索覆盖笔记、文件夹、文档和说话人，支持高亮和匹配定位。',
 '07':'展示真实 JWD 服务核实、连接、电量、录音与传输状态；使用 Teno/JWD 通用设备图标。',
 '09':'保留暂停/停止、文字与时间高亮，并增加录音照片；设备断连不声称已停止。',
 '14':'补 New note、多笔记列表、封面、独立编辑与版本；旧摘要保留并投射到新界面。',
 '15':'真实波形、章节、跟随播放和前后跳转；原稿/编辑稿/清理稿分开，姓名按录音版本保存。',
 '17':'Teno 自有推荐模板、分类/搜索、收藏/最近使用和自建编辑；不伪造官方社区内容。',
 '19':'Chat 支持录音、笔记、文件夹和文档上下文；语音识别结果先显示为可编辑文字。',
 '21':'设置分组包含通知、主题、缓存和默认关闭的系统凭据应用锁。',
 '22':'Cloud processing 缺省开启，显式 false 保留；不因首次录音设置而阻止自动处理，不补传历史未申请文件。',
 '23':'按内容/格式/选项导出真实 MP3/WAV/TXT/MD/SRT/DOCX/PDF/JSON；时间、姓名、标记和封面可选。',
 '26':'From Files / From Photos / From other apps；多文件先完整保存，再按账号设置进入持久队列。',
 '27':'用户显式创建固定版本链接；默认仅摘要、7天、不带音频，支持撤销，来源删除后失效。',
 '28':'手机日历、手动和 ICS 导入；可关联录音，不接入第三方 OAuth。',
 '32':'独立文字笔记与引用来源；编辑/重新生成保存为修订，原版本保留。',
 '34':'服务端本地提取/OCR，保存页码与来源；Word 渲染后定位实际页，损坏/加密/超限明确报错。',
 '35':'完整本机副本、手动/批量上传和状态；失败保留原文件及稳定 client_id。',
 '37':'查看本机副本与缓存用量；清缓存不删除录音原文件。',
 '39':'空态保持原页面结构，提供已实现的录音和导入路径。',
 '41':'连接失败仍可访问本机文件，显示原因和重试。',
 '43':'结果高亮，录音定位时间、文档定位页码，笔记打开对应内容。',
 '45':'多选管理；合并只对多条录音开放，生成新记录并保留原文件。',
 '49':'手动命名限定当前录音和转写版本；重新转写后重新核对，不跨录音猜身份。',
 '50':'查找替换保存编辑修订，原始 ASR 内容完整保留。',
 '51':'按秒选取裁剪范围，异步生成新录音；合并同样保留原始文件。',
 '54':'独立笔记版本可追溯；重新生成保留原文和原摘要。',
 '56':'系统权限拒绝时明确提示，可使用手动/ICS 日历路径。',
 '57':'解析失败显示原因并保留原文件，可重试。',
 '59':'外部分享先暂存，用户登录后明确接受到当前账号。',
 '61':'长标题可编辑；系统键盘区域下保留保存入口。',
 '62':'转写/摘要失败停止无限等待，提供原因与重试；静音文件保留音频。',
}
css='body{font:16px/1.65 system-ui;background:#f7f8f9;color:#191c1f;margin:0}main{max-width:1000px;margin:auto;padding:28px}article{padding:20px;border:1px solid #ddd;background:white;border-radius:12px}nav{display:flex;gap:20px;flex-wrap:wrap}button,select{padding:10px 15px;margin:6px;border:1px solid #ccc;border-radius:8px;background:white;cursor:pointer}img{display:block;max-width:min(440px,100%);height:auto;margin:20px auto;border:1px solid #ddd}a{color:#245987}small{color:#626a70}li{margin:8px 0}'
pages=OUT/'pages';pages.mkdir(parents=True,exist_ok=True);records=[]
files=sorted((OUT/'screenshots/android/light').glob('*.png'))
for index,file in enumerate(files):
    key=file.stem;code=key[:2];ref_id=mapping.get(code);ref=references.get(ref_id);variants=[]
    for mode in ('light','dark','large'):
        shot=OUT/'screenshots/android'/mode/file.name;assert shot.is_file(),shot
        variants.append({'name':mode,'screenshot':shot.relative_to(OUT).as_posix(),'sha256':hashlib.sha256(shot.read_bytes()).hexdigest()})
    original=[images[n] for n in (ref['refs'] if ref else []) if n in images]
    inferred=not ref or bool(ref.get('proposed')) or int(code)>=34
    note=changes.get(code,changes.get(ref_id,'沿用对应核心页面布局，并补齐本状态的操作与错误反馈。'))
    record={'id':key,'title':key[3:].replace('-',' ').title(),'reference_id':ref_id,'official_sources':original,
        'inferred_state':inferred,'change':note,'variants':variants,'evidence':'Current Flutter code rendered with synthetic data; no physical-device claim.',
        'acceptance':'Current Android analysis/layout/interaction regression passed; physical Magic4 Pro/JWD pending.'}
    records.append(record)
    previous=files[index-1].stem;next_id=files[(index+1)%len(files)].stem
    reference_html=''.join(f'<option value="{html.escape(v["url"],quote=True)}">官方原图 {i+1}</option>' for i,v in enumerate(original))
    source_html='、'.join(f'<a href="{html.escape(v["article"],quote=True)}">官方帮助文档</a>' for v in original)
    page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Teno0.6.0 · {key}</title><style>{css}</style><main><nav><a href="../index.html">全部页面</a><a href="{previous}.html">上一页</a><a href="{next_id}.html">下一页</a></nav><h1>{html.escape(record['title'])}</h1><article><strong>官方原图 → 当前页面 → 改动 → 验收</strong><p>{html.escape(note)}</p><p>{'本状态含设计推定；官方资料用于周边布局依据，未取得同状态整页原图。' if inferred else '有对应的官方4.x帮助截图依据；原图中的iOS系统栏不作为Android系统栏模板。'}</p><small>当前图片来自本轮Flutter页面代码和合成资料，并非真机/真实JWD验收。官方截图不等于已运行原版APK。{source_html}</small></article><p>{''.join(f'<button onclick="show(\'../{v["screenshot"]}\',\'{v["name"]}\')">{v["name"]}</button>' for v in variants)}<select onchange="show(this.value,\'官方原图\')"><option value="">选择官方原图</option>{reference_html}</select></p><p id="label">Teno · light</p><img id="screen" src="../{variants[0]['screenshot']}" alt="{html.escape(record['title'])}"><script>function show(path,label){{if(!path)return;document.getElementById('screen').src=path;document.getElementById('label').textContent=label}}</script><p>验收：{record['acceptance']}</p></main></html>'''
    (pages/(key+'.html')).write_text(page,encoding='utf-8')
(OUT/'pages.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
intro='Teno0.6.0 · Android逐页差异与验收'
index=f'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{intro}</title><style>{css}</style><main><h1>{intro}</h1><article>本轮共{len(records)}个独立页面/状态，每页有浅色、深色和360dp/1.5倍字号截图。逐页可切换官方原图。PLAUD依据为官方4.x帮助资料；缺图状态标明推定。真实Android系统选择器另见本轮原生验收；Magic4 Pro/JWD实机待验收。<p><a href="differences-and-acceptance.txt">独立差异与验收文档</a> · <a href="../index.html">0.5.0历史稿</a></p></article><ol>'+''.join(f'<li><a href="pages/{r["id"]}.html">{r["id"]}</a> {"（含推定）" if r["inferred_state"] else ""}</li>' for r in records)+'</ol></main></html>'
native=OUT/'native-pages.json'
if native.is_file():
    native_rows=json.loads(native.read_text(encoding='utf-8'))
    native_links='<article><strong>本轮原生模拟器截图</strong><ul>'+''.join('<li><a href="'+html.escape(r['path'],quote=True)+'">'+html.escape(r['id'])+'</a></li>' for r in native_rows)+'</ul><small>实际API35模拟器画面；合成账号；不等于Magic4 Pro或JWD实机验收。</small></article>'
    index=index.replace('<ol>',native_links+'<ol>',1)
(OUT/'index.html').write_text(index,encoding='utf-8')
test_log=(ROOT/'verification/v0.6.0/android-checks.log').read_text(encoding='utf-8',errors='replace')
test_count=int(re.search(r'\+(\d+):[^\n]*All tests passed!',test_log)[1])
lines=[intro,'','版本：Android0.6.0 / versionCode11；共享后端1.4.0 / 增量迁移007。',
    '范围：本轮个人核心。JWD、Automatic、Azure/DeepSeek、账号隔离和完整本机保留沿用。',
    '保留差异：音视频120分钟/250MiB；无本人声纹、Agent、Work、Tasks、Skills、Routines、Connectors、支付、团队或第三方登录。',
    '证据边界：Flutter测试截图使用合成资料。官方截图含iOS系统栏；Android系统栏/键盘/选择器按系统规范。缺少对应原图的状态明确标为推定，不称像素级复刻或原版运行验收。',
    f'验证：本轮Android分析和{test_count}项Flutter回归通过；后端198项隔离回归、34张旧业务表迁移前后哈希、旧端11项/新端16项恢复库兼容、21项正式HTTPS检查通过。',
    '真实供应商：75.263秒中英合成语音、2个返回说话人标签、18项检查、4条Usage；结果在隔离恢复库，非客户录音质量/实机验证。',
    '边界：120分钟分段和完整时间轴已做合成/隔离验证；未进行接近120分钟的付费供应商调用。Magic4 Pro和真实JWD仍待人工验收。',
    'Cloud processing：未配置默认开启，明确关闭保持；先完整保存再排队。Wi-Fi限制和重启恢复沿用持久队列；旧未申请文件不自动补传。',
    '文档/OCR：本地处理，Word渲染页码；200页/10分钟/一百万提取字符保护，超过限制明确报错并保留原文件。',
    '交付不自动提升0.5.0已确认基线，不合并main，不发布应用商店，本轮不构建iOS。','']
for r in records:
    lines += [r['id']+' · '+r['title'], '原图：'+('；'.join(v['article'] for v in r['official_sources']) or '无同页官方原图，按已确认范围推定'),
        '改动：'+r['change'],'状态：'+('含推定；' if r['inferred_state'] else '')+r['acceptance'],
        '截图：'+', '.join(v['screenshot'] for v in r['variants']),'']
(OUT/'differences-and-acceptance.txt').write_text('\n'.join(lines),encoding='utf-8')
print(json.dumps({'pages':len(records),'screenshots':sum(len(v['variants']) for v in records),'inferred_states':sum(v['inferred_state'] for v in records)}))
