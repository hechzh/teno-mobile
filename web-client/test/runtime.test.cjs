const {test} = require('node:test');
const assert = require('node:assert/strict');
const {TenoWebRuntime, RecordingCache, fileInfo} = require('../web/runtime.js');
class Storage {
  values = new Map();
  getItem(k) { return this.values.get(k); }
  setItem(k, v) { this.values.set(k, v); }
  removeItem(k) { this.values.delete(k); }
}
class Store {
  values = new Map();
  async get(id) { return structuredClone(this.values.get(id)); }
  async put(d) { this.values.set(d.id, structuredClone(d)); }
  async list(scope) { return [...this.values.values()].filter(d => d.scope === scope).map(d => structuredClone(d)); }
  async delete(id) { this.values.delete(id); }
  async all() { return [...this.values.values()].map(d => structuredClone(d)); }
}
const response = (data, status = 200) => new Response(JSON.stringify(data), {status, headers: {'Content-Type': 'application/json'}});
const user = {id: 'user-a', username: 'synthetic', access_token: 'access-a', refresh_token: 'refresh-a'};
function host(fetch) {
  const runtime = new TenoWebRuntime({origin: 'https://teno.example', storage: new Storage(), store: new Store(), fetch});
  runtime.session = {...user}; runtime.validated = true; return runtime;
}
const file = (name = 'acceptance.txt') => new File(['Synthetic Teno acceptance content.'], name, {type: 'text/plain'});
test('0.8.2 import language survives failed upload, reload and opposite UI preference', async () => {
  const bodies=[];const r=host(async (url,options) => { bodies.push([options.body.get('client_id'),options.body.get('output_language'),options.body.get('output_language_origin')]); throw new Error('offline'); });
  await r.call('interface_locale',{locale:'zh'});
  const {items}=await r.stage([file('sample.wav')]);const id=items[0].id;
  await r.retryUpload({id});
  await r.call('interface_locale',{locale:'en'});
  const restored=new TenoWebRuntime({origin:r.origin,store:r.store,storage:r.storage,fetch:r.fetch});restored.session={...user};restored.validated=true;
  await restored.loadDrafts();await restored.retryUpload({id});
  assert.deepEqual(bodies,[[id,'zh-CN','interface'],[id,'zh-CN','interface']]);
  const following=await restored.stage([file('second.wav')]);assert.equal((await restored.store.get(following.items[0].id)).output_language,'en-US');
});
test('0.8.2 one-off language applies to documents and does not modify account settings', async () => {
  let fields;const r=host(async(url,options)=>{fields=options.body;return response({file_id:'synthetic-file'},202);});r.settings={summary_language:'en-US'};
  await r.call('interface_locale',{locale:'en'});
  const result=await r.stage([file()],r.epoch,'teno:actions',{output_language:'zh-CN',output_language_origin:'override'});
  await r.retryUpload({id:result.items[0].id});
  assert.equal(fields.get('output_language'),'zh-CN');assert.equal(fields.get('template_id'),'teno:actions');assert.equal(r.settings.summary_language,'en-US');
  const next=await r.stage([file('next.txt')]);assert.equal((await r.store.get(next.items[0].id)).output_language,'en-US');
});
test('0.8.2 server note failure wins over older saved notes and keeps browser original', async () => {
  const r=host(async()=>response({stage:'generating_note',status:'failed',stage_status:'failed',preserved:{notes:1,transcript:true}}));
  const {items}=await r.stage([file('sample.wav')]);const d=await r.owned(items[0].id);d.recording_id='record';await r.store.put(d);await r.loadDrafts();
  await r.pollProcessing();const p=r.view().drafts[0].processing;
  assert.equal(p.stage_status,'failed');assert.equal(p.preserved.notes,1);assert.equal(p.preserved.local_file,true);assert.equal(p.percent,undefined);
});
test('template selection persists locally, freezes at upload and retry preserves it', async () => {
  const submitted = []; let fail = true;
  const r = host(async (url, options) => {
    if (url.endsWith('/recordings')) {
      submitted.push({id: options.body.get('client_id'), template: options.body.get('template_id')});
      if (fail) throw new Error('Network interrupted');
      return response({recording_id:'record', job_id:'job'},202);
    }
    return response({status:'ready'});
  });
  const {items} = await r.stage([file('meeting.wav')],r.epoch,'teno:lecture');
  const id=items[0].id;
  await r.call('note_template',{id,template_id:'teno:interview'});
  assert.equal((await r.store.get(id)).template_id,'teno:interview');
  await r.retryUpload({id});
  assert.equal((await r.store.get(id)).status, 'failed');
  await assert.rejects(r.call('note_template',{id,template_id:'teno:actions'}),/Processing has started/);
  fail=false; await r.retryUpload({id});
  assert.deepEqual(submitted,[{id,template:'teno:interview'},{id,template:'teno:interview'}]);
  assert.ok((await r.store.get(id)).blob.size);
});
test('only supported types and true byte limits enter browser storage', () => {
  assert.equal(fileInfo(file()).kind, 'file');
  assert.equal(fileInfo({name: 'MEETING.M4A', size: 100}).kind, 'recording');
  assert.throws(() => fileInfo({name: 'empty.txt', size: 0}), /empty/);
  assert.throws(() => fileInfo({name: 'huge.txt', size: 2000001}), /limit/);
  assert.throws(() => fileInfo({name: 'code.html', size: 1}), /supported/);
  assert.throws(() => fileInfo({name: 'large.wav', size: 262144001}), /limit/);
});
test('credentials can only be sent to the same-origin API', async () => {
  let calls = 0; const r = host(async () => { calls++; return response({}); });
  for (const path of ['https://evil.example/api/v1/me', '//evil.example/api/v1/me', '/api/v1/../../team', 'https://name:secret@teno.example/api/v1/me'])
    await assert.rejects(r.request({method: 'GET', path}));
  assert.equal(calls, 0);
});
test('complete narrative edits retain their scope and text through the browser runtime', async () => {
  let sent;
  const r = host(async (url, options) => {
    sent = {url, method: options.method, body: JSON.parse(options.body)};
    return response({id: 'note-1', revision: 2});
  });
  const body = {title: 'Synthetic review', body: 'Overview\n\nFull prose\n\nNext steps', revision: 1, body_scope: 'complete'};
  await r.call('request', {method: 'PATCH', path: '/api/v1/notes/note-1', body});
  assert.equal(sent.url, 'https://teno.example/api/v1/notes/note-1');
  assert.equal(sent.method, 'PATCH');
  assert.deepEqual(sent.body, body);
});
test('concurrent expired requests rotate the session once, both retry', async () => {
  let refreshes = 0;
  const r = host(async (url, options) => {
    if (url.endsWith('/auth/refresh')) {
      refreshes++; await new Promise(resolve => setTimeout(resolve, 10));
      return response({access_token: 'access-b', refresh_token: 'refresh-b'});
    }
    return options.headers.Authorization === 'Bearer access-b' ? response({id: 'ok'}) : response({}, 401);
  });
  const result = await Promise.all([r.request({method: 'GET', path: '/api/v1/me'}), r.request({method: 'GET', path: '/api/v1/me'})]);
  assert.equal(refreshes, 1); assert.deepEqual(result, [{id: 'ok'}, {id: 'ok'}]);
  assert.equal(JSON.parse(r.storage.getItem('teno.web.session')).refresh_token, 'refresh-b');
});
test('rejected refresh clears visible account data', async () => {
  const r = host(async () => response({}, 401)); r.drafts = [{id: 'private'}];
  await assert.rejects(r.request({method: 'GET', path: '/api/v1/me'}));
  assert.equal(r.session, null); assert.deepEqual(r.view().drafts, []);
});
test('logout during a request rejects its stale account result', async () => {
  let finish; const r = host(() => new Promise(resolve => finish = resolve));
  const pending = r.request({method: 'GET', path: '/api/v1/me'});
  r.clear(); r.session = {...user, id: 'user-b'};
  finish(response({id: 'user-a', private: 'old account'}));
  await assert.rejects(pending, /Account changed/);
});
test('picker cancellation creates no draft and does not upload', async () => {
  const r = host(() => assert.fail('must not call server'));
  assert.deepEqual(await r.stage([]), {items: []}); assert.equal(r.store.values.size, 0);
});
test('batch validation happens before saving or sending any file', async () => {
  const r = host(() => assert.fail('must not call server'));
  await assert.rejects(r.stage([file(), file('script.html')]), /supported/);
  assert.equal(r.store.values.size, 0);
});
test('staged files retain complete bytes and are hidden from another account', async () => {
  const r = host(() => assert.fail('manual upload required'));
  const {items} = await r.stage([file()]);
  assert.equal(await (await r.owned(items[0].id)).blob.text(), await file().text());
  const view = r.view(); assert.equal('blob' in view.drafts[0], false); assert.equal('access_token' in view.session, false);
  r.session = {...user, id: 'user-b'}; await r.loadDrafts();
  assert.deepEqual(r.view().drafts, []); await assert.rejects(r.owned(items[0].id), /unavailable/);
});
test('retry after ambiguous network failure reuses exact client ID and bytes', async () => {
  const calls = []; let fail = true;
  const r = host(async (url, options) => {
    calls.push({url, id: options.body.get('client_id'), text: await options.body.get('file').text()});
    if (fail) throw new Error('network');
    return response({file_id: 'remote-1', job_id: 'job-1'}, 202);
  });
  const {items} = await r.stage([file()]); const id = items[0].id;
  await r.retryUpload({id}); assert.equal((await r.owned(id)).status, 'failed');
  fail = false; await r.retryUpload({id});
  assert.equal((await r.owned(id)).file_id, 'remote-1'); assert.equal(calls[0].id, calls[1].id); assert.equal(calls[0].text, calls[1].text);
  await r.retryUpload({id}); assert.equal(calls.length, 2);
});
test('media uses existing personal import pipeline with Automatic language', async () => {
  let sent;
  const r = host(async (url, options) => { sent = {url, body: options.body}; return response({recording_id: 'record-1'}, 202); });
  const {items} = await r.stage([file('synthetic.wav')]); await r.retryUpload({id: items[0].id});
  assert.equal(sent.url, 'https://teno.example/api/v1/recordings');
  for (const [key, value] of Object.entries({language: 'auto', personal_mode: 'true', source: 'import'})) assert.equal(sent.body.get(key), value);
});
test('reload retains interrupted files for explicit safe retry', async () => {
  const r = host(async () => response({id: 'user-a', username: 'synthetic'}));
  const {items} = await r.stage([file()]); const d = await r.owned(items[0].id); d.status = 'uploading'; await r.store.put(d);
  r.validated = false; await r.snapshot();
  assert.equal(r.drafts[0].status, 'failed'); assert.ok(r.drafts[0].blob.size > 0);
});
test('search history is scoped to the active account', async () => {
  const r = host(() => assert.fail('history is local'));
  await r.call('history', {query: 'one'}); await r.call('history', {query: 'two'}); await r.call('history', {query: 'one'});
  assert.deepEqual(await r.call('history', {}), {items: ['one', 'two']});
  r.session = {...user, id: 'user-b'}; assert.deepEqual(await r.call('history', {}), {items: []});
});
test('disabled browser storage does not block the existing cloud library', async () => {
  const r = host(async () => response({id: 'user-a', username: 'synthetic'}));
  r.store.list = async () => { throw new Error('Storage unavailable'); };
  r.validated = false;
  assert.equal((await r.snapshot()).session.signedIn, true);
});
test('sign-out during upload retains the original account copy for retry', async () => {
  let finish, started;
  const ready = new Promise(resolve => started = resolve);
  const r = host(() => new Promise(resolve => { finish = resolve; started(); }));
  const {items} = await r.stage([file()]); const id = items[0].id;
  const upload = r.retryUpload({id}); await ready;
  r.clear(); r.session = {...user, id: 'user-b'};
  finish(response({file_id: 'remote-1'}, 202)); await upload;
  assert.equal((await r.store.get(id)).scope, 'user-a');
  assert.equal((await r.store.get(id)).status, 'failed');
  assert.deepEqual(r.view().drafts, []);
});

const bundle = (id = 'record-1', revision = 1) => ({record: {id, revision, duration_ms: 2461896},
  transcript: {recording_id: id, revision, segments: [{id: 'segment-1', text: 'Saved transcript'}]},
  notes: [{id: 'note-1', data: {summary: 'Saved note'}}], metadata: {}, processing: {status: 'ready'}, peaks: [.2, .6, .1]});
const read = (r, id = 'record-1', variant = 'edited') => r.call('recording_cache', {action: 'read', id, variant});
async function save(r, value = bundle(), variant = 'edited', token) {
  token ??= (await read(r, value.record.id, variant)).token;
  return r.call('recording_cache', {action: 'write', id: value.record.id, variant, token, value});
}
function cachedHost(fetch = () => assert.fail('cache never calls model or HTTP'), options = {}) {
  const r = host(fetch); r.readCache = new RecordingCache({store: new Store(), ...options}); return r;
}
test('recording, note and waveform cache survive a reload under the same validated account', async () => {
  const store = new Store(), r = cachedHost(undefined, {store}); await save(r);
  const reloaded = cachedHost(undefined, {store});
  assert.deepEqual((await read(reloaded)).value, bundle());
  reloaded.validated = false; assert.deepEqual(await read(reloaded), {});
  reloaded.validated = true; reloaded.session = {...user, id: 'user-b'};
  assert.equal((await read(reloaded)).value, null);
});
test('transcript variants have separate entries and caller edits do not mutate stored snapshots', async () => {
  const r = cachedHost(); await save(r);
  const cleaned = bundle(); cleaned.transcript.segments[0].text = 'Cleaned transcript';
  await save(r, cleaned, 'cleaned');
  const edited = (await read(r)).value; edited.transcript.segments[0].text = 'Caller change';
  assert.equal((await read(r)).value.transcript.segments[0].text, 'Saved transcript');
  assert.equal((await read(r, 'record-1', 'cleaned')).value.transcript.segments[0].text, 'Cleaned transcript');
});
test('logout purges read cache while preserving retained imports', async () => {
  const r = cachedHost(); await save(r); await r.stage([file()]);
  r.clear(); await r.readCache.queue;
  assert.equal(r.readCache.entries.size, 0); assert.equal(r.store.values.size, 1);
  r.session = {...user}; r.validated = true; assert.equal((await read(r)).value, null);
});
test('stale writes from a previous account cannot repopulate its cache after sign-out', async () => {
  const r = cachedHost(), old = await read(r); r.clear();
  r.session = {...user, id: 'user-b'}; r.validated = true;
  await save(r, bundle(), 'edited', old.token); assert.equal((await read(r)).value, null);
});
for (const path of ['/api/v1/notes/n1', '/api/v1/recordings/record-1/transcriptions', '/api/v1/jobs/job-1/retry']) {
  test(`mutation invalidates cached content and older pending snapshots: ${path}`, async () => {
    const r = cachedHost(async () => response({})); await save(r); const old = await read(r);
    await r.request({method: 'POST', path, body: {}});
    await save(r, bundle(), 'edited', old.token);
    assert.equal((await read(r)).value, null);
  });
}
test('an ambiguous mutation failure invalidates the old cache too', async () => {
  const r = cachedHost(async () => { throw Error('lost connection'); }); await save(r);
  await assert.rejects(r.request({method: 'PATCH', path: '/api/v1/notes/n1', body: {}}));
  assert.equal((await read(r)).value, null);
});
for (const status of [403, 404]) {
  test(`deleted or inaccessible recordings are evicted (${status})`, async () => {
    const r = cachedHost(async () => response({}, status)); await save(r);
    await assert.rejects(r.request({method: 'GET', path: '/api/v1/recordings/record-1'}), /RECORDING_UNAVAILABLE/);
    assert.equal((await read(r)).value, null);
  });
}
test('network failure retains cached data for a visibly marked offline fallback', async () => {
  const r = cachedHost(async () => { throw Error('offline'); }); await save(r);
  await assert.rejects(r.request({method: 'GET', path: '/api/v1/recordings/record-1'}));
  assert.deepEqual((await read(r)).value, bundle());
});
test('concurrent reads share one request but a later read checks the server again', async () => {
  let finish, calls = 0;
  const r = cachedHost(() => { calls++; return new Promise(resolve => finish = resolve); });
  const args = {method: 'GET', path: '/api/v1/recordings/record-1/waveform'};
  const a = r.request(args), b = r.request(args); finish(response({peaks: [.4]}));
  assert.deepEqual(await a, await b); assert.equal(calls, 1);
  const c = r.request(args); finish(response({peaks: [.6]})); await c; assert.equal(calls, 2);
});
test('storage failure falls back to memory without blocking cloud requests', async () => {
  const store = new Store(); store.all = store.put = store.delete = async () => { throw Error('quota'); };
  const r = cachedHost(async () => response({id: 'ok'}), {store}); await save(r);
  assert.deepEqual((await read(r)).value, bundle());
  assert.deepEqual(await r.request({method: 'GET', path: '/api/v1/me'}), {id: 'ok'});
});
test('cache evicts least recently used entries, expires snapshots and enforces byte limits', async () => {
  let now = 1000; const r = cachedHost(undefined, {now: () => now, maxEntries: 2, maxBytes: 2000, maxAge: 100});
  await save(r); now++; await save(r, bundle('record-2')); now++;
  await read(r); now++; await save(r, bundle('record-3'));
  assert.equal((await read(r, 'record-2')).value, null); assert.ok((await read(r)).value);
  const huge = bundle('huge'); huge.transcript.segments[0].text = '大'.repeat(1000); await save(r, huge);
  assert.equal((await read(r, 'huge')).value, null);
  now += 101; assert.equal((await read(r)).value, null);
});
test('clear cache reports real storage and does not remove import drafts', async () => {
  const r = cachedHost(); await save(r); await r.stage([file()]);
  assert.ok((await r.call('storage', {})).cache_bytes > 0);
  await r.call('clear_cache', {});
  assert.equal((await r.call('storage', {})).cache_bytes, 0); assert.equal(r.store.values.size, 1);
});
test('a write already in browser storage is removed when invalidated mid-write', async () => {
  const store = new Store(); let finish, started;
  const ready = new Promise(resolve => started = resolve);
  store.put = async entry => { started(); await new Promise(resolve => finish = resolve); store.values.set(entry.id, entry); };
  const r = cachedHost(undefined, {store}), pending = save(r); await ready;
  r.clear(); finish(); await pending; await r.readCache.queue;
  assert.equal(store.values.size, 0); assert.equal(r.readCache.entries.size, 0);
});
