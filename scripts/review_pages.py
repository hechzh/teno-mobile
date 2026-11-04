"""Build a local, one-page-at-a-time implementation review from test captures."""
import hashlib, html, json
from pathlib import Path

repo=Path(__file__).resolve().parents[1]
source=repo.parent/'design-review/plaud-rebuild/20261104'
output=repo/'design-baseline'
pages=output/'pages'; pages.mkdir(parents=True,exist_ok=True)
manifest=json.loads((source/'page-manifest.json').read_text(encoding='utf-8'))
references={p['id']:p for p in manifest}
mapping={
 '01-home':'01','02-navigation':'02','03-create-menu':'03','04-library':'04','05-folder':'05','06-search':'06',
 '07-device-connect':'07','08-device-connected':'08','09-recording':'09','10-paused':'10','11-stop-confirmation':'09','12-device-transfer':'12',
 '14-summary':'14','15-transcript':'15','16-transcript-editor':'16','18-ask-history':'18','19-ask-chat':'20','20-ask-context':'31','23-tools':'25',
 '24-template-picker':'13','25-template-editor':'17','29-settings':'21','30-preferences':'22','32-trash':'24','33-export':'23',
 '34-login':None,'35-local-files':None,'36-local-recording':'29','37-recording-keyboard':'11','38-live-preview':'09',
 '39-device-interrupted':'30','40-upload-failed':'30','41-new-chat':'19','42-summary-editor':'14',
 '43-microphone-denied':None,'44-offline-library':'04','45-folder-options':'33',
}
notes={
 '01':'首版聚焦录音时间流；日历/Upcoming 不在本期列明范围，不放置虚构日程。',
 '02':'Teno / Ask Teno；保留 Home、Library、Ask、Tools、Settings，Tools 只开放模板；不显示虚构分钟额度。',
 '03':'右上展开菜单；JWD 为主、手机为小字次级入口。',
 '04':'录音与文件夹、自动保留的本机文件、回收站；无照片/团队资料。',
 '05':'复用现有资料库与文件夹接口；按创建时间分页。首版没有拖拽或批量管理。',
 '06':'复用标题和转写全文检索；没有原版说话人/日期组合筛选。',
 '07':'按真实 JWD GATT 服务、独立密钥与现有绑定信息连接。图标为通用录音器符号，非 PLAUD 硬件。',
 '08':'显示真实连接回调及电量，录音/下载操作等待硬件确认。截图中的设备数据仅来自测试替身。',
 '09':'Pause/Stop/计时、Type/Highlight；照片入口隐藏；实时字幕放在可展开区域。',
 '10':'暂停保持同一面板；恢复与停止等待回调。',
 '11':'时间高亮保存为带时间标记的文字笔记；不创建独立新笔记。',
 '12':'下载长度、结束标记、可用 CRC 和严格解码全部通过后才保存到上传队列。',
 '13':'Automatic 固定；使用现有摘要模板，生成语言从 Preferences 设置；没有模型/声纹切换。',
 '14':'摘要页通过 Audio & transcript 进入独立转写页；版本、编辑和 Ask 保留。不提供独立新笔记和公开分享链接。',
 '15':'真实原生播放器、时间跳转、倍速、分段转写编辑；不绘制虚构音频波形。',
 '16':'通过段落编辑弹窗和 revision 校验保存，冲突时重新加载。',
 '17':'使用现有账号模板，支持创建与编辑；不伪造官方/社区模板市场。',
 '18':'现有问答会话历史；仅 Ask Teno，不带 Work/Tasks/Routines。',
 '19':'问答输入与录音上下文选择。',
 '20':'现有后端问答、引用与时间定位；消息内容为测试数据。',
 '21':'保留设置分组，入口收敛到录音、存储、账号及帮助；无团队/声纹管理。',
 '22':'Automatic、云处理、Wi-Fi 上传、实时预览、生成语言；本机保留不可自动关闭。',
 '23':'音频及文字格式通过 Android/iOS 系统分享面板导出。',
 '24':'逐条恢复与二次确认后的永久删除；未提供原版批量选择工具栏。',
 '25':'只保留 Templates，不显示 Skills/Connectors。',
 '26':'系统音频文件选择器；不显示照片导入或分享扩展。',
 '27':'公开链接和邀请隐藏；系统分享是首版出口。',
 '28':'本期首版范围不包含日历。',
 '29':'本机保存、上传和云处理为不同状态；结果读取既有接口。',
 '30':'断连不等于停止；坏文件不上传；完整本机文件可使用同一 client_id 重试。',
 '31':'仅选择已有且完成转写的录音，最多 30 条；不带技能/照片/相机。',
 '32':'独立新笔记入口隐藏；录音过程的文字笔记继续保留。',
 '33':'通过文件夹菜单及 Trash 入口管理；不提供尚未实现的批量选择/排序选项。',
}
css='''body{font:16px/1.65 system-ui,sans-serif;background:#f7f8f8;color:#16191b;margin:0}main{max-width:1000px;margin:auto;padding:32px}h1{line-height:1.2;font-size:30px}a{color:#28577a}nav{display:flex;gap:22px;flex-wrap:wrap}small,.muted{color:#626a70}button{padding:10px 18px;border:1px solid #cbd1d4;border-radius:8px;background:white;cursor:pointer;margin:0 12px 16px 0}img{display:block;width:min(390px,100%);height:auto;margin:22px auto;border:1px solid #d9dfe2;border-radius:12px}article{padding:20px;background:white;border:1px solid #e1e5e6;border-radius:12px}li{margin:12px 0}table{width:100%;border-collapse:collapse}td,th{text-align:left;padding:12px;border-bottom:1px solid #dce1e3}code{overflow-wrap:anywhere}'''
records=[]
screens=sorted((output/'screenshots/shared').glob('*.png'))
for number,file in enumerate(screens):
    key=file.stem; ref_id=mapping.get(key); ref=references.get(ref_id)
    title=key.replace('-',' ').title()
    ref_url='../../../design-review/plaud-rebuild/20261104/'+ref['png'] if ref else ''
    ref_html='../../../design-review/plaud-rebuild/20261104/'+ref['html'] if ref else ''
    png='../screenshots/shared/'+file.name
    record={'id':key,'title':title,'reference_id':ref_id,'screenshot':'screenshots/shared/'+file.name,'screenshot_sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'evidence':'Flutter widget-test render with synthetic data; not a device screenshot','reference_runtime_tested':False,'implementation_note':notes.get(ref_id,'按首版登录、权限和本机存储要求补充。')}
    variants=[]
    for folder,label in [('ios-shared','iOS 样式'),('shared/large-text','Android · 大字'),('ios-shared/large-text','iOS · 大字')]:
        variant=output/'screenshots'/folder/file.name
        if variant.is_file():
            relative='screenshots/'+folder+'/'+file.name
            variants.append({'label':label,'screenshot':relative,'sha256':hashlib.sha256(variant.read_bytes()).hexdigest()})
    record['variants']=variants
    records.append(record)
    prev=screens[number-1].stem if number else screens[-1].stem
    nxt=screens[(number+1)%len(screens)].stem
    reference_button=f'<button onclick="showReference()">查看当前基准</button>' if ref else ''
    reference_info=f'<p>参考：<a href="{ref_html}">{html.escape(ref["title"])}</a>。{html.escape(ref["gaps"])}<br>版本依据：{html.escape(ref["version_basis"])}；未实测原包此状态。</p>' if ref else '<p>此页按已确认的 Teno 首版要求补充，没有对应的原版整页证据。</p>'
    page=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Teno · {title}</title><style>{css}</style><main><nav><a href="../index.html">全部页面</a><a href="{prev}.html">上一页</a><a href="{nxt}.html">下一页</a></nav><h1>{title}</h1><article><strong>Teno 0.5.0 · 单页实现核对</strong><p>{html.escape(record['implementation_note'])}</p><small>默认图片是实际 Flutter 页面代码的测试渲染，使用合成账号、文本和设备状态。不是 Android/iOS 真机截图，不能作为 BLE 或识别准确率证明。</small>{reference_info}</article><p><button onclick="showTeno()">Teno 实现</button>{reference_button}<a href="{png}">独立 PNG</a></p><p id="label" class="muted">Teno · Flutter 测试渲染</p><img id="page" src="{png}" alt="{title}"><script>function showTeno(){{document.getElementById('page').src={json.dumps(png)};document.getElementById('label').textContent='Teno · Flutter 测试渲染'}}function showReference(){{document.getElementById('page').src={json.dumps(ref_url)};document.getElementById('label').textContent='当前 PLAUD 参考设计 · 原资料保留品牌 · 非运行实录'}}</script></main></html>'''
    (pages/(key+'.html')).write_text(page,encoding='utf-8')
    buttons=''.join('<button onclick="showVariant('+html.escape(json.dumps('../'+v['screenshot']),quote=True)+','+html.escape(json.dumps(v['label'],ensure_ascii=False),quote=True)+')">'+v['label']+'</button>' for v in variants)
    page=page.replace('Teno 实现</button>','Android 样式</button>'+buttons)
    page=page.replace('<script>','<script>function showVariant(src,label){document.getElementById("page").src=src;document.getElementById("label").textContent="Teno · "+label+" · Flutter 测试渲染"}')
    (pages/(key+'.html')).write_text(page,encoding='utf-8')
coverage=[]
for ref in manifest:
    coverage.append({'reference_id':ref['id'],'title':ref['title'],'reference_html':ref['html'],'reference_sha256':hashlib.sha256((source/ref['html']).read_bytes()).hexdigest(),'official_refs':ref['refs'],'reference_inferred':ref['proposed'],'runtime_tested':False,'scope':'hidden' if ref['id'] in ['27','28','32'] else 'implemented_or_adapted','note':notes[ref['id']],'implementation_pages':[p['id'] for p in records if p['reference_id']==ref['id']]})
(output/'pages.json').write_text(json.dumps({'product':'Teno','version':'0.5.0','reference_manifest_sha256':hashlib.sha256((source/'page-manifest.json').read_bytes()).hexdigest(),'pages':records,'reference_coverage':coverage},ensure_ascii=False,indent=2),encoding='utf-8')
links=''.join(f'<li><a href="pages/{p["id"]}.html">{p["title"]}</a></li>' for p in records)
table=''.join(f'<tr><td>{p["reference_id"]} {html.escape(p["title"])}</td><td>{html.escape(p["note"])}</td></tr>' for p in coverage)
index=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Teno · 逐页实现核对</title><style>{css}</style><main><h1>Teno · 逐页实现核对</h1><p>每个链接只展示一个页面，可切换查看当前参考设计；没有拼成长图。产品品牌为 Teno / Ask Teno。</p><article><p>设计源：20261104 的 33 页。官方宣传图确切版本并非全部可确定；静态拆解、设计推定不代表实机流程。原始参考保持原样。</p><p>本目录图片由实际 Flutter 页面代码渲染，使用合成测试内容。Android/iOS 原生运行和硬件验收另见 RELEASE-0.5.0.txt。系统文件选择器、系统分享面板、蓝牙授权由各平台呈现。</p><a href="../ARCHITECTURE.txt">架构</a> · <a href="pages.json">逐页追溯清单与文件哈希</a> · <a href="../RELEASE-0.5.0.txt">验证记录</a></article><ol>{links}</ol><h2>33 页基准的首版处理</h2><table><tr><th>原页面</th><th>首版范围</th></tr>{table}</table></main></html>'''
index=index.replace('<ol>','<p><a href="native.html">原生模拟器截图与测试记录</a></p><ol>',1)
(output/'index.html').write_text(index,encoding='utf-8')
native=[]
for platform in ['android','ios']:
    file=output/'screenshots/native'/('01-login-'+platform+'.png')
    if file.is_file():
        native.append((platform,'screenshots/native/'+file.name))
if native:
    buttons=''.join('<button onclick="document.getElementById(\'native\').src='+html.escape(json.dumps(p),quote=True)+'">'+k.title()+'</button>' for k,p in native)
    body=f'''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Teno · 原生模拟器</title><style>{css}</style><main><a href="index.html">返回逐页核对</a><h1>Teno · 原生模拟器</h1><article><p>以下图片来自原生宿主实际启动后的模拟器截屏，每次展示一张。Android 为本机 API 35，iOS 为 GitHub macOS runner 上的 iOS Simulator。均不是实体设备验收。</p><p>详细验证及已知边界：<a href="../RELEASE-0.5.0.txt">内测记录</a>。页面代码测试渲染在主索引单独展示。</p></article><p>{buttons}</p><img id="native" src="{native[0][1]}" alt="Teno 原生模拟器登录页"></main></html>'''
    (output/'native.html').write_text(body,encoding='utf-8')
print(f'{len(records)} separate review pages; {len(coverage)} baseline pages accounted for.')
