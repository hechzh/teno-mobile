const {test} = require('node:test');
const assert = require('node:assert/strict');
const {TenoWebRuntime} = require('../web/runtime.js');
class Storage { values = new Map(); getItem(k) {return this.values.get(k);} setItem(k,v) {this.values.set(k,v);} removeItem(k) {this.values.delete(k);} }
for (const unavailable of [false,true]) test(`UI locale persists without changing session or queue (storage unavailable=${unavailable})`, async () => {
 const storage = unavailable ? {getItem(){throw Error('blocked');},setItem(){throw Error('blocked');}} : new Storage();
 let requests=0;
 const runtime = new TenoWebRuntime({origin:'https://teno.example',storage,fetch:()=>{requests++;throw Error('No request expected');}});
 const session = runtime.session, queue = runtime.drafts;
 assert.equal((await runtime.call('interface_locale', {})).locale, 'system');
 assert.equal((await runtime.call('interface_locale', {locale:'zh'})).locale, 'zh');
 assert.equal((await runtime.call('interface_locale', {})).locale, 'zh');
 assert.strictEqual(runtime.session,session); assert.strictEqual(runtime.drafts,queue);assert.equal(requests,0);
 if(!unavailable){const reopened=new TenoWebRuntime({origin:'https://teno.example',storage});assert.equal((await reopened.call('interface_locale', {})).locale,'zh');}
 await assert.rejects(runtime.call('interface_locale', {locale:'unsupported'}));
 assert.equal((await runtime.call('interface_locale', {})).locale,'zh');
});
