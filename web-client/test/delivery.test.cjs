const test = require('node:test'), assert = require('node:assert/strict');
const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path');
const code = fs.readFileSync(path.join(__dirname,'../web/delivery.js'),'utf8');
function setup({query='',fetcher}={}) {
  const calls=[], nodes=[], listeners={}, storage=new Map();
  const metadata={'teno-assets':'_static/id/','teno-main-sha':'expected','teno-cdn':'https://cdn.example/pinned/,https://edge.example/pinned/'};
  const context={URL,AbortController,TextDecoder,Uint8Array,Promise,setTimeout,clearTimeout,
    localStorage:{getItem:k=>storage.get(k),setItem:(k,v)=>storage.set(k,v)},addEventListener:(name,fn)=>listeners[name]=fn,
    location:{href:'https://teno.example/app/'+query},
    document:{baseURI:'https://teno.example/app/',querySelector:s=>({content:metadata[s.match(/"([^"]+)"/)[1]]}),
      addEventListener:(name,fn)=>listeners[name]=fn,
      createElement:()=>({remove(){this.removed=true}}),head:{appendChild:n=>nodes.push(n)}},
    async fetch(url,opts){calls.push({url:String(url),opts});return fetcher?fetcher(url,opts):{ok:true,async arrayBuffer(){return new TextEncoder().encode('{"main":"expected"}').buffer}}}};
  vm.createContext(context);vm.runInContext(code,context);return {context,calls,nodes,listeners,api:context.tenoAssets};
}
test('selects a verified pinned CDN and never sends credentials or referrers',async()=>{
  const p=setup();const url=await p.api.select();assert.equal(url.origin,'https://cdn.example');
  assert.equal(await p.api.select(),url);assert.equal(p.calls.length,2);
  assert.ok(p.calls.every(c=>c.opts.credentials==='omit'&&c.opts.referrerPolicy==='no-referrer'));
  assert.equal(p.api.isResource('https://cdn.example/pinned/main.dart.js'),true);
  assert.equal(p.api.isResource('https://cdn.example/private/recording'),false);
});
test('blocked and wrong-version CDNs fall back without blocking the original server',async()=>{
  for(const fail of [true,false]) {
    const p=setup({fetcher:async()=>{if(fail)throw Error('offline');return{ok:true,async arrayBuffer(){return new TextEncoder().encode('{"main":"wrong"}').buffer}}}});
    assert.equal((await p.api.select()).origin,'https://teno.example');assert.equal(p.api.source,'origin');
  }
  const p=setup({query:'?teno_assets=origin'});assert.equal((await p.api.select()).origin,'https://teno.example');assert.equal(p.calls.length,0);
});
test('a source is remembered only after first frame, and reused for warm HTTP cache',async()=>{
 const p=setup();await p.api.select();assert.equal(p.context.localStorage.getItem('teno.web.asset-source'),undefined);
 p.listeners['flutter-first-frame']();const saved=p.context.localStorage.getItem('teno.web.asset-source');
 const q=setup();q.context.localStorage.setItem('teno.web.asset-source',saved);await q.api.select();assert.equal(q.calls.length,1);assert.equal(q.api.source,p.api.source);
 const newer=setup();newer.context.localStorage.setItem('teno.web.asset-source',JSON.stringify({main:'old',base:'https://cdn.example/pinned/'}));await newer.api.select();assert.equal(newer.calls.length,2);
 const failed=setup({fetcher:async url=>{if(String(url).includes('cdn.example'))throw Error('offline');return {ok:true,async arrayBuffer(){return new TextEncoder().encode('{"main":"expected"}').buffer}}}});
 failed.context.localStorage.setItem('teno.web.asset-source',saved);await failed.api.select();assert.equal(failed.api.source,'edge.example');
});
test('blocked browser storage does not prevent static source selection',async()=>{
 const p=setup();Object.defineProperty(p.context,'localStorage',{get(){throw Error('SecurityError')}});
 await p.api.select();p.listeners['flutter-first-frame']();assert.equal(p.api.source,'cdn.example');
});
test('content font failure retries only the same immutable path on origin',async()=>{
  const p=setup();await p.api.select();p.context.fetch=async url=>{
    if(new URL(url).host!=='teno.example')throw Error('CDN failed');
    assert.equal(new URL(url).pathname,'/app/_static/id/assets/assets/fonts/subsets/common-001.woff2');
    return {ok:true,async arrayBuffer(){return new Uint8Array([1,2,3]).buffer}};
  };
  assert.deepEqual(Array.from(await p.api.bytes('assets/fonts/subsets/common-001.woff2')),[1,2,3]);
  await assert.rejects(p.api.bytes('../api/private'));await assert.rejects(p.api.bytes('https://third.example/private'));
});
test('deferred page retries on origin; it never evaluates response text',async()=>{
  const p=setup();await p.api.select();let loaded=false;
  const done=new Promise((resolve,reject)=>p.context.dartDeferredLibraryLoader('https://cdn.example/pinned/main.dart.js_3.part.js',()=>{loaded=true;resolve()},reject));
  await new Promise(resolve=>setTimeout(resolve,0));
  assert.equal(p.nodes[0].crossOrigin,'anonymous');p.nodes[0].onerror();
  await new Promise(resolve=>setTimeout(resolve,0));assert.equal(p.nodes[1].src,'https://teno.example/app/_static/id/main.dart.js_3.part.js');
  p.nodes[1].onload();await done;assert.equal(loaded,true);
  let rejected=false;p.context.dartDeferredLibraryLoader('https://example.com/not-a-page.js',()=>assert.fail(),()=>rejected=true);assert.equal(rejected,true);
});
test('IME hook ignores password and unrelated document inputs',()=>{
  const p=setup();const values=[];p.api.listenInput(value=>values.push(value));
  for(const[type,match]of[['password',true],['text',false],['text',true]])p.listeners.input({target:{type,value:'生僻字',classList:{contains:()=>match}}});
  assert.deepEqual(values,['生僻字']);
 p.listeners.input({target:{},composedPath:()=>[{type:'text',value:'上海',classList:{contains:()=>true}}]});
 assert.deepEqual(values,['生僻字','上海']);
 p.listeners.input({target:{type:'text',value:'中文',getAttribute:()=> 'text-field'}});
 assert.deepEqual(values,['生僻字','上海','中文']);
});
test('several Dart fragments share one transfer and can retry after a failed group',async()=>{
 const p=setup();await p.api.select();p.context.fetch=async()=>({ok:true,async arrayBuffer(){return new TextEncoder().encode(JSON.stringify({parts:{'main.dart.js_1.part.js':'pages-shared.part.js','main.dart.js_2.part.js':'pages-shared.part.js'}})).buffer}});
 const load=name=>new Promise((resolve,reject)=>p.context.dartDeferredLibraryLoader(name,resolve,reject));
 const a=load('main.dart.js_1.part.js'),b=load('main.dart.js_2.part.js');await new Promise(resolve=>setTimeout(resolve,0));
 assert.equal(p.nodes.length,1);assert.match(p.nodes[0].src,/pages-shared\.part\.js$/);p.nodes[0].onload();await Promise.all([a,b]);
 await load('main.dart.js_1.part.js');assert.equal(p.nodes.length,1);
});
