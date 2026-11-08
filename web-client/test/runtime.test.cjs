const {test} = require('node:test');
const assert = require('node:assert/strict');
const {TenoWebRuntime, fileInfo} = require('../web/runtime.js');
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
}
const response = (data, status = 200) => new Response(JSON.stringify(data), {status, headers: {'Content-Type': 'application/json'}});
const user = {id: 'user-a', username: 'synthetic', access_token: 'access-a', refresh_token: 'refresh-a'};
function host(fetch) {
  const runtime = new TenoWebRuntime({origin: 'https://teno.example', storage: new Storage(), store: new Store(), fetch});
  runtime.session = {...user}; runtime.validated = true; return runtime;
}
const file = (name = 'acceptance.txt') => new File(['Synthetic Teno acceptance content.'], name, {type: 'text/plain'});
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
