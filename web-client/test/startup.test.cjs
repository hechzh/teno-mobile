const {test} = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname,'../web/startup.js'),'utf8');
function page({locale='zh-CN',saved=null,blocked=false}={}) {
  const listeners={}, nodes={}, timers=new Map(); let next=0, now=0, writes=0, reloads=0;
  for(const id of ['loading','loading-status','loading-hint','loading-actions','loading-compatible','loading-copy','loading-retry','loading-diagnostics'])
    nodes[id]={hidden:true,textContent:'',attributes:{},onclick:null,removed:false,
      addEventListener(name,fn){this['on'+name]=fn;},setAttribute(k,v){this.attributes[k]=v;},remove(){this.removed=true;},focus(){},select(){}};
  const location={origin:'https://teno.example',href:'https://teno.example/app-preview/?token=NEVER_COPY#private',reload(){reloads++},replace(url){this.href=url}};
  const context={document:{getElementById:id=>nodes[id],documentElement:{},baseURI:'https://teno.example/app-preview/',querySelector:()=>({content:'_static/abcd/'})},
    navigator:{language:locale,onLine:true,clipboard:{async writeText(text){context.copied=text;}}},URL,location,
    localStorage:{getItem(){if(blocked)throw Error('storage blocked');return saved;},setItem(){writes++;}},
    performance:{now:()=>now,getEntriesByType:()=>[
      {name:'https://teno.example/app-preview/_static/abcd/main.dart.js?token=PRIVATE',duration:25,encodedBodySize:100,transferSize:200},
      {name:'https://teno.example/api/v1/recordings/secret?access_token=NO',duration:5},
      {name:'https://third.example/main.js',duration:2}]},
    setTimeout(fn,ms){timers.set(++next,{fn,ms});return next},clearTimeout(id){timers.delete(id)},
    addEventListener(name,fn){(listeners[name]??=[]).push(fn)}};
  vm.createContext(context);vm.runInContext(source,context);
  return {nodes,context,fire:(name,event={})=>(listeners[name]||[]).forEach(fn=>fn(event)),tick(ms){now=ms;for(const[id,t]of timers)if(t.ms<=ms){timers.delete(id);t.fn();}},
    get writes(){return writes},get reloads(){return reloads},timers};
}
test('slow startup becomes actionable, and timeout preserves the in-flight attempt',()=>{
 const p=page();assert.match(p.nodes['loading-status'].textContent,/下载/);
 p.tick(15000);assert.equal(p.nodes['loading-actions'].hidden,false);
 p.tick(45000);assert.match(p.nodes['loading-status'].textContent,/尚未完成/);assert.equal(p.nodes.loading.removed,false);
 p.context.tenoStartup.stage('engine');assert.match(p.nodes['loading-hint'].textContent,/加载时间较长/);
 p.fire('flutter-first-frame');assert.equal(p.nodes.loading.removed,true);assert.equal(p.timers.size,0);assert.equal(p.writes,0);
});
test('failed static resources produce a retry and diagnostic without clearing any storage',()=>{
 const p=page();p.fire('error',{target:{src:'https://teno.example/app-preview/_static/abcd/main.dart.js?secret=HIDDEN'}});
 assert.match(p.nodes['loading-status'].textContent,/未能启动/);p.nodes['loading-retry'].onclick();assert.equal(p.reloads,1);assert.equal(p.writes,0);
 const data=p.context.tenoStartup.diagnostics();assert.match(data,/resource-error/);assert.doesNotMatch(data,/HIDDEN|NEVER_COPY|PRIVATE|secret|recordings|third\.example/);
});
test('offline and denied storage still provide localized recovery controls',()=>{
 const p=page({blocked:true});p.context.navigator.onLine=false;p.fire('offline');assert.match(p.nodes['loading-status'].textContent,/网络已断开/);
 const q=page({locale:'zh-CN',saved:'en'});assert.match(q.nodes['loading-status'].textContent,/Downloading/);
});
test('compatibility mode is explicit and only offered after the entry point loads',()=>{
 const p=page();p.tick(15000);assert.equal(p.nodes['loading-compatible'].hidden,true);
 p.context.tenoStartup.stage('engine');assert.equal(p.nodes['loading-compatible'].hidden,false);
 p.nodes['loading-compatible'].onclick();assert.equal(new URL(p.context.location.href).searchParams.get('teno_render'),'cpu');assert.equal(p.writes,0);
});
test('diagnostics have a manual copy fallback; late errors do not affect a running app',async()=>{
 const p=page();p.context.navigator.clipboard.writeText=async()=>{throw Error('blocked')};await p.nodes['loading-copy'].onclick();
 assert.equal(p.nodes['loading-diagnostics'].hidden,false);assert.match(p.nodes['loading-diagnostics'].value,/Teno/);
 p.fire('flutter-first-frame');const before=p.nodes['loading-status'].textContent;p.fire('unhandledrejection');assert.equal(p.nodes['loading-status'].textContent,before);
});
test('a restricted sessionStorage getter and BroadcastChannel cannot prevent runtime creation',()=>{
 const context={fetch(){},location:{origin:'https://teno.example'},document:{},URL,Map,Set,JSON,TextEncoder,console,
   BroadcastChannel:class{constructor(){throw Error('not allowed')}},addEventListener(){},
   get sessionStorage(){throw Error('SecurityError')}};
 vm.createContext(context);vm.runInContext(fs.readFileSync(path.join(__dirname,'../web/runtime.js'),'utf8'),context);
 assert.equal(typeof context.tenoWeb.call,'function');
});
test('custom initializer receives the exact asset and rendering configuration',async()=>{
 const stages=[];let loaderConfig,engineConfig;
 const context={URL,document:{baseURI:'https://teno.example/app-preview/',querySelector:()=>({content:'_static/abcd/'})},
   location:{href:'https://teno.example/app-preview/?teno_render=cpu'},
   tenoStartup:{stage:s=>stages.push(s),fail:s=>assert.fail(s)},
   _flutter:{loader:{async load({config,onEntrypointLoaded}){loaderConfig=config;await onEntrypointLoaded({async initializeEngine(c){engineConfig=c;return {async runApp(){}}}})}}}};
 vm.createContext(context);
 const template=fs.readFileSync(path.join(__dirname,'../web/flutter_bootstrap.js'),'utf8').replace(/\{\{flutter_(?:js|build_config)\}\}/g,'');
 await vm.runInContext(template,context);
 assert.strictEqual(loaderConfig,engineConfig);assert.equal(engineConfig.assetBase,'https://teno.example/app-preview/_static/abcd/');
 assert.equal(engineConfig.canvasKitForceCpuOnly,true);assert.deepEqual(stages,['engine','interface']);
});
