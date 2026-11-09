/* Browser-only host for the shared Flutter interface. No provider/device keys. */
(() => {
  'use strict';
  const MEDIA = new Set(['wav', 'mp3', 'm4a', 'aac', 'flac', 'ogg', 'mp4', 'mov', '3gp', 'webm']);
  const DOCUMENTS = new Set(['pdf', 'doc', 'docx', 'pptx', 'msg']);
  const IMAGES = new Set(['png', 'jpg', 'jpeg']);
  function fileInfo(file) {
    const ext = file.name.split('.').pop().toLowerCase();
    const limit = MEDIA.has(ext) ? 262144000 : IMAGES.has(ext) ? 20000000 :
      DOCUMENTS.has(ext) ? 15000000 : ['txt', 'md'].includes(ext) ? 2000000 : 0;
    if (!limit) throw new Error('Choose a supported audio, video, document or PNG/JPEG file.');
    if (!file.size) throw new Error('The selected file is empty.');
    if (file.size > limit) throw new Error(`${file.name}: exceeds the file size limit.`);
    return {kind: MEDIA.has(ext) ? 'recording' : 'file', ext};
  }
  class BrowserStore {
    constructor(database = 'teno-web-imports-v1', table = 'imports') { this.database = database; this.table = table; }
    async open() {
      if (this.db) return this.db;
      this.db = await new Promise((resolve, reject) => {
        const r = indexedDB.open(this.database, 1);
        r.onupgradeneeded = () => r.result.createObjectStore(this.table, {keyPath: 'id'});
        r.onsuccess = () => resolve(r.result);
        r.onerror = () => reject(new Error('Browser storage is unavailable. Allow website storage and retry.'));
        r.onblocked = () => reject(new Error('Close other Teno tabs and retry.'));
      });
      return this.db;
    }
    async transaction(mode, run) {
      const db = await this.open();
      return new Promise((resolve, reject) => {
        const tx = db.transaction(this.table, mode);
        const result = run(tx.objectStore(this.table));
        tx.oncomplete = () => resolve(result.result);
        tx.onerror = tx.onabort = () => reject(new Error('Could not save the file in this browser. Free up storage and retry.'));
      });
    }
    get(id) { return this.transaction('readonly', s => s.get(id)); }
    put(value) { return this.transaction('readwrite', s => s.put(value)); }
    delete(id) { return this.transaction('readwrite', s => s.delete(id)); }
    async list(scope) { return (await this.transaction('readonly', s => s.getAll())).filter(d => d.scope === scope); }
    all() { return this.transaction('readonly', s => s.getAll()); }
  }
  // Separate from retained imports: this is disposable, account-scoped read data.
  class RecordingCache {
    constructor({store = new BrowserStore('teno-web-read-cache-v1', 'recordings'), now = Date.now,
      maxEntries = 24, maxBytes = 8 * 1024 * 1024, maxAge = 7 * 86400000} = {}) {
      this.store = store; this.now = now; this.maxEntries = maxEntries; this.maxBytes = maxBytes; this.maxAge = maxAge;
      this.entries = new Map(); this.queue = Promise.resolve(); this.loaded = false;
    }
    run(action) {
      const task = this.queue.then(async () => {
        if (!this.loaded) {
          try { for (const entry of await this.store.all()) this.entries.set(entry.id, entry); } catch (_) {}
          this.loaded = true;
        }
        return action();
      });
      this.queue = task.catch(() => {}); return task;
    }
    async remove(id) { this.entries.delete(id); try { await this.store.delete(id); } catch (_) {} }
    async prune() {
      const entries = [...this.entries.values()].sort((a, b) => b.touched - a.touched);
      let count = 0, bytes = 0;
      for (const entry of entries) {
        if (!Number.isFinite(entry.bytes) || this.now() - entry.savedAt > this.maxAge || entry.savedAt > this.now() ||
            ++count > this.maxEntries || (bytes += entry.bytes) > this.maxBytes) await this.remove(entry.id);
      }
    }
    get(scope, id, variant) {
      return this.run(async () => {
        await this.prune();
        const entry = this.entries.get(JSON.stringify([scope, id, variant]));
        if (!entry || entry.scope !== scope) return null;
        entry.touched = this.now();
        return JSON.parse(JSON.stringify(entry.value));
      });
    }
    put(scope, id, variant, value, valid) {
      return this.run(async () => {
        if (!valid()) return;
        const json = JSON.stringify(value), bytes = new TextEncoder().encode(json).length;
        if (bytes > this.maxBytes) return;
        const entry = {id: JSON.stringify([scope, id, variant]), scope, value: JSON.parse(json), bytes,
          savedAt: this.now(), touched: this.now()};
        this.entries.set(entry.id, entry);
        try { await this.store.put(entry); } catch (_) { /* Memory cache still works when storage is full or disabled. */ }
        if (!valid()) await this.remove(entry.id);
        await this.prune();
      });
    }
    clear(scope) {
      return this.run(async () => {
        for (const entry of [...this.entries.values()]) if (entry.scope === scope) await this.remove(entry.id);
      });
    }
    size(scope) { return this.run(async () => { await this.prune(); return [...this.entries.values()].filter(e => e.scope === scope).reduce((n, e) => n + e.bytes, 0); }); }
  }
  class TenoWebRuntime {
    constructor(options = {}) {
      this.fetch = options.fetch || globalThis.fetch.bind(globalThis);
      this.origin = options.origin || location.origin;
      try { this.storage = options.storage || sessionStorage; } catch (_) {
        // Some private/embedded browsers reject even reading sessionStorage.
        // The session can still live in memory for this tab.
        const values = new Map();
        this.storage = {getItem: k => values.get(k) ?? null,
          setItem: (k, v) => values.set(k, v), removeItem: k => values.delete(k)};
      }
      this.store = options.store || new BrowserStore();
      this.readCache = options.readCache || new RecordingCache(); this.cacheGeneration = 0;
      this.reads = new Map();
      if (typeof document !== 'undefined' && typeof BroadcastChannel !== 'undefined') {
        try {
          this.cacheChannel = new BroadcastChannel('teno-web-read-cache-v1');
          this.cacheChannel.onmessage = event => {
            if (event.data?.scope === this.session?.id) this.invalidateCache(false);
          };
        } catch (_) { /* Restricted browsers keep the account-scoped in-tab cache. */ }
      }
      this.session = null; this.epoch = 0; this.sequence = 0; this.drafts = [];
      this.controllers = new Set(); this.uploads = new Map(); this.settings = {};
      this.player = {ready: false, playing: false, positionMs: 0, durationMs: 0, speed: 1, mediaId: '', error: ''};
      this.urls = new Set(); this.listeners = []; this.validated = false; this.playSequence = 0;
      try { this.session = JSON.parse(this.storage.getItem('teno.web.session') || 'null'); } catch (_) {}
      if (!this.session?.access_token || !this.session?.refresh_token || !this.session?.id) this.session = null;
    }
    listen(listener) { this.listeners.push(listener); }
    view() {
      return {sequence: ++this.sequence, session: {
        signedIn: !!this.session, username: this.session?.username || '',
        scope: this.session?.id || 'signed-out', server: this.origin,
      }, playback: this.player,
      drafts: this.drafts.map(({blob, scope, ...safe}) => safe),
      uploadStatus: this.uploads.size ? 'Uploading · Keep this tab open' : ''};
    }
    emit() { const state = JSON.stringify(this.view()); for (const fn of this.listeners) fn(state); }
    persist() {
      try { this.session ? this.storage.setItem('teno.web.session', JSON.stringify(this.session)) : this.storage.removeItem('teno.web.session'); }
      catch (_) { /* In-memory login still works when session storage is disabled. */ }
    }
    check(epoch) { if (epoch !== this.epoch || !this.session) throw new Error('Account changed. Sign in and retry.'); }
    safePath(path) {
      const url = new URL(path, this.origin);
      if (url.origin !== this.origin || !url.pathname.startsWith('/api/v1/') || url.username || url.password)
        throw new Error('This request is not a Teno API request.');
      return url.href;
    }
    async responseError(response) {
      const data = await response.json().catch(() => ({}));
      const detail = data.detail || data.error || data;
      const error = new Error(typeof detail.message === 'string' ? detail.message :
        response.status === 413 ? 'This file exceeds the upload limit.' :
        response.status === 401 ? 'Your session expired. Sign in again.' :
        response.status === 429 ? 'Too many requests. Please try again shortly.' : 'The request could not be completed. Please retry.');
      error.status = response.status; return error;
    }
    async raw(path, options = {}, timeout = 90000, externalSignal) {
      const controller = new AbortController(); this.controllers.add(controller);
      const abort = () => controller.abort();
      externalSignal?.addEventListener('abort', abort, {once: true});
      if (externalSignal?.aborted) controller.abort();
      const timer = setTimeout(abort, timeout);
      try {
        return await this.fetch(this.safePath(path), {...options, credentials: 'omit', cache: 'no-store', redirect: 'error', signal: controller.signal});
      } catch (error) {
        throw new Error(controller.signal.aborted ? 'Upload or request stopped. Retry when ready.' : 'Connection interrupted. Check your internet connection and retry.');
      } finally {
        clearTimeout(timer); this.controllers.delete(controller);
        externalSignal?.removeEventListener('abort', abort);
      }
    }
    async refresh(epoch) {
      this.check(epoch);
      if (this.refreshing) return this.refreshing;
      const task = (async () => {
        const r = await this.raw('/api/v1/auth/refresh', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({refresh_token: this.session.refresh_token})});
        this.check(epoch);
        if (!r.ok) {
          if (r.status === 401) this.clear();
          throw await this.responseError(r);
        }
        const pair = await r.json(); this.check(epoch);
        this.session = {...this.session, ...pair}; this.persist();
      })();
      this.refreshing = task;
      try { await task; } finally { if (this.refreshing === task) this.refreshing = null; }
    }
    async authorized(path, options = {}, timeout, signal) {
      const epoch = this.epoch; this.check(epoch);
      let token = this.session.access_token;
      const run = () => this.raw(path, {...options, headers: {...options.headers, Authorization: `Bearer ${this.session.access_token}`}}, timeout, signal);
      let response = await run(); this.check(epoch);
      if (response.status === 401) {
        if (this.session.access_token === token) await this.refresh(epoch);
        this.check(epoch); response = await run(); this.check(epoch);
      }
      if (!response.ok) throw await this.responseError(response);
      return response;
    }
    async request(args) {
      const {method, path} = args;
      if (method.toUpperCase() !== 'GET') return this.requestOnce(args);
      this.safePath(path); this.check(this.epoch);
      const key = this.cacheToken() + path;
      if (this.reads.has(key)) return this.reads.get(key);
      const pending = this.requestOnce(args); this.reads.set(key, pending);
      try { return await pending; } finally { this.reads.delete(key); }
    }
    async requestOnce({method, path, body}) {
      const epoch = this.epoch;
      this.safePath(path); this.check(epoch);
      const mutation = !['GET', 'HEAD'].includes(method.toUpperCase());
      if (mutation) this.invalidateCache();
      try {
        const result = await this.authorized(path, {method, ...(body == null ? {} : {headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)})});
        const value = result.status === 204 ? {} : await result.json(); this.check(epoch);
        return value;
      } catch (error) {
        if ([401, 403, 404].includes(error.status) && /\/recordings\/[^/]+(?:\/|\?|$)/.test(path)) {
          this.invalidateCache();
          throw new Error('RECORDING_UNAVAILABLE: This recording is no longer available.');
        }
        throw error;
      } finally { if (mutation && epoch === this.epoch) this.invalidateCache(); }
    }
    cacheToken() { return JSON.stringify([this.session?.id, this.epoch, this.cacheGeneration]); }
    invalidateCache(broadcast = true) {
      ++this.cacheGeneration;
      const scope = this.session?.id;
      if (!scope) return Promise.resolve();
      if (broadcast) this.cacheChannel?.postMessage({scope});
      return this.readCache.clear(scope).catch(() => {});
    }
    async recordingCache(args) {
      const epoch = this.epoch; this.check(epoch);
      if (!this.validated) return {};
      const scope = this.session.id, token = this.cacheToken();
      if (args.action === 'clear') { await this.invalidateCache(); return {}; }
      if (typeof args.id !== 'string' || !args.id || !['edited', 'original', 'cleaned'].includes(args.variant)) return {};
      if (args.action === 'read') {
        const value = await this.readCache.get(scope, args.id, args.variant); this.check(epoch);
        return token === this.cacheToken() ? {token, value} : {};
      }
      if (args.action === 'write' && args.token === token && args.value?.record?.id === args.id) {
        const value = Object.fromEntries(['record', 'transcript', 'notes', 'metadata', 'processing', 'peaks']
          .filter(key => key in args.value).map(key => [key, args.value[key]]));
        await this.readCache.put(scope, args.id, args.variant, value,
          () => epoch === this.epoch && token === this.cacheToken());
      }
      return {};
    }
    async loadDrafts() {
      const epoch = this.epoch, scope = this.session?.id;
      let drafts = [];
      try { drafts = scope ? await this.store.list(scope) : []; }
      catch (_) { /* Cloud library remains usable if browser storage is disabled. Import reports its own error. */ }
      if (epoch !== this.epoch) return;
      this.drafts = drafts.sort((a, b) => b.created_at.localeCompare(a.created_at));
    }
    async snapshot() {
      if (this.session && !this.validated) {
        const me = await this.request({method: 'GET', path: '/api/v1/me'});
        this.session = {...this.session, id: me.id, username: me.username};
        this.validated = true; this.persist();
        await this.loadDrafts();
        // A page reload cannot prove whether the server accepted an upload. Reuse its ID on retry.
        for (const d of this.drafts) if (['uploading', 'queued'].includes(d.status)) {
          d.status = 'failed'; d.error = 'Upload interrupted. Retry to check or complete it safely.';
          await this.store.put(d);
        }
      }
      return this.view();
    }
    async login({username, password}) {
      const epoch = this.epoch;
      const r = await this.raw('/api/v1/auth/login', {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify({username, password})});
      if (!r.ok) throw await this.responseError(r);
      const pair = await r.json();
      if (epoch !== this.epoch) throw new Error('Sign-in cancelled.');
      this.session = {...pair, id: 'authenticating', username}; this.validated = false;
      try { await this.snapshot(); } catch (e) { this.clear(); throw e; }
      this.emit(); return {};
    }
    clear() {
      this.invalidateCache();
      ++this.epoch; for (const c of this.controllers) c.abort();
      for (const c of this.uploads.values()) c.abort();
      this.session = null; this.validated = false; this.drafts = []; this.settings = {}; this.refreshing = null;
      this.resetPlayer(); this.persist(); this.emit();
    }
    async logout() {
      const token = this.session?.access_token;
      this.clear();
      if (token) await this.raw('/api/v1/auth/logout', {method: 'POST', headers: {Authorization: `Bearer ${token}`}}, 10000).catch(() => {});
      return {};
    }
    async pick({source}) {
      const epoch = this.epoch; this.check(epoch);
      // The picker must open in the original user gesture before any awaits.
      const files = await new Promise((resolve) => {
        const input = document.createElement('input'); input.type = 'file'; input.multiple = true;
        input.accept = source === 'photos' ? '.png,.jpg,.jpeg' : '.wav,.mp3,.m4a,.aac,.flac,.ogg,.mp4,.mov,.3gp,.webm,.pdf,.doc,.docx,.pptx,.msg,.txt,.md,.png,.jpg,.jpeg';
        input.style.display = 'none'; document.body.appendChild(input);
        const finish = () => { const values = Array.from(input.files || []); input.remove(); resolve(values); };
        input.addEventListener('change', finish, {once: true});
        input.addEventListener('cancel', finish, {once: true});
        input.click();
      });
      this.check(epoch);
      return this.stage(files, epoch);
    }
    async stage(files, epoch = this.epoch) {
      this.check(epoch);
      if (files.length > 20) throw new Error('Choose up to 20 files at a time.');
      const checked = files.map(file => ({file, ...fileInfo(file)}));
      const items = [];
      try {
        for (const {file, kind} of checked) {
          this.check(epoch);
          const d = {id: crypto.randomUUID(), scope: this.session.id, title: file.name, kind, status: 'local',
            created_at: new Date().toISOString(), size: file.size, blob: file, error: '', recording_id: '', file_id: ''};
          await this.store.put(d); this.check(epoch); items.push({id: d.id, type: 'local', title: d.title});
        }
      } finally { await this.loadDrafts(); this.emit(); }
      return {items};
    }
    async owned(id) {
      const epoch = this.epoch; this.check(epoch);
      const d = await this.store.get(id); this.check(epoch);
      if (!d || d.scope !== this.session.id) throw new Error('File unavailable for this account.');
      return d;
    }
    async retryUpload({id}) {
      const epoch = this.epoch, d = await this.owned(id);
      if (this.uploads.has(id)) return {};
      if (d.recording_id || d.file_id) return {};
      const run = async () => {
        this.check(epoch);
        const current = await this.owned(id);
        if (current.recording_id || current.file_id) { await this.loadDrafts(); this.emit(); return; }
        const controller = new AbortController(); this.uploads.set(id, controller);
        d.status = 'uploading'; d.error = ''; await this.store.put(d); await this.loadDrafts(); this.emit();
        try {
          const form = new FormData(); form.append('file', d.blob, d.title); form.append('client_id', d.id);
          if (d.kind === 'recording') {
            form.append('title', d.title); form.append('language', 'auto');
            form.append('personal_mode', 'true'); form.append('source', 'import');
          }
          const r = await this.authorized(d.kind === 'recording' ? '/api/v1/recordings' : '/api/v1/files', {method: 'POST', body: form}, 1200000, controller.signal);
          const result = await r.json();
          // This result belongs to d.scope even if the user signed out while the server accepted it.
          d.recording_id = result.recording_id || ''; d.file_id = result.file_id || '';
          if (!d.recording_id && !d.file_id) throw new Error('Upload result was incomplete. Retry safely.');
          d.status = 'uploaded'; d.error = ''; d.job_id = result.job_id || '';
        } catch (e) { d.status = 'failed'; d.error = e.message; }
        finally {
          await this.store.put(d); this.uploads.delete(id);
          if (epoch === this.epoch) { await this.loadDrafts(); this.emit(); }
        }
      };
      // Cross-tab lock protects the retained file and its one upload identity.
      if (globalThis.navigator?.locks) await navigator.locks.request(`teno-import-${id}`, {ifAvailable: true}, async lock => {
        if (!lock) throw new Error('This file is uploading in another tab.');
        await run();
      }); else await run();
      return {};
    }
    async deleteLocal({id}) {
      await this.owned(id);
      if (this.uploads.has(id)) throw new Error('Stop the upload before deleting this browser copy.');
      await this.store.delete(id); await this.loadDrafts(); this.emit(); return {};
    }
    resetPlayer() {
      if (this.audio) { this.audio.pause(); this.audio.removeAttribute('src'); this.audio.load(); }
      for (const url of this.urls) URL.revokeObjectURL(url); this.urls.clear();
      this.player = {ready: false, playing: false, positionMs: 0, durationMs: 0, speed: 1, mediaId: '', error: ''};
      ++this.playSequence;
    }
    async playback({action, id, local, positionMs, speed}) {
      if (action === 'stop') { this.resetPlayer(); this.emit(); return {}; }
      const epoch = this.epoch; this.check(epoch);
      if (!this.audio) {
        this.audio = new Audio(); this.audio.preload = 'metadata';
        for (const name of ['timeupdate', 'durationchange', 'play', 'pause', 'ended', 'error']) this.audio.addEventListener(name, () => {
          this.player = {...this.player, ready: this.audio.readyState >= 1, playing: !this.audio.paused,
            positionMs: Math.round((this.audio.currentTime || 0) * 1000),
            durationMs: Math.round((Number.isFinite(this.audio.duration) ? this.audio.duration : 0) * 1000),
            error: this.audio.error ? 'This audio cannot be played in this browser.' : this.player.error};
          this.emit();
        });
      }
      if (this.player.mediaId !== id) {
        this.resetPlayer(); const playSequence = this.playSequence;
        this.player.mediaId = id; this.emit();
        const blob = local ? (await this.owned(id)).blob : await (await this.authorized(`/api/v1/recordings/${encodeURIComponent(id)}/audio`)).blob();
        this.check(epoch);
        if (playSequence !== this.playSequence) return {};
        const url = URL.createObjectURL(blob); this.urls.add(url); this.audio.src = url;
        await new Promise((resolve, reject) => {
          const timer = setTimeout(() => finish(new Error('Audio could not be loaded. Retry playback.')), 30000);
          const ready = () => finish(), fail = () => finish(new Error('This audio cannot be played in this browser.'));
          const finish = error => { clearTimeout(timer); this.audio.removeEventListener('loadedmetadata', ready); this.audio.removeEventListener('error', fail); error ? reject(error) : resolve(); };
          this.audio.addEventListener('loadedmetadata', ready, {once: true}); this.audio.addEventListener('error', fail, {once: true}); this.audio.load();
        });
      }
      this.check(epoch);
      if (action === 'pause') this.audio.pause();
      if (['play', 'seek'].includes(action)) this.audio.currentTime = Math.max(0, Math.min(positionMs / 1000, this.audio.duration));
      if (action === 'speed') { this.audio.playbackRate = speed; this.player.speed = speed; }
      if (['play', 'seek'].includes(action)) {
        this.player.error = '';
        try { await this.audio.play(); }
        catch (_) { this.player.error = 'Audio ready. Tap Play to allow playback.'; this.emit(); }
      }
      this.emit(); return {};
    }
    async download(args, local = false) {
      const epoch = this.epoch; this.check(epoch);
      const d = local ? await this.owned(args.id) : null;
      const response = local ? null : await this.authorized(args.path);
      const blob = local ? d.blob : await response.blob(); this.check(epoch);
      const url = URL.createObjectURL(blob); this.urls.add(url);
      const link = document.createElement('a'); link.href = url;
      const disposition = response?.headers.get('Content-Disposition') || '';
      let filename = d?.title || `Teno.${args.format || 'txt'}`;
      const encoded = /filename\*=UTF-8''([^;]+)/i.exec(disposition), plain = /filename="?([^";]+)/i.exec(disposition);
      try { filename = encoded ? decodeURIComponent(encoded[1]) : plain ? plain[1] : filename; } catch (_) {}
      link.download = filename.replace(/[\\/]/g, '_'); link.rel = 'noopener';
      document.body.appendChild(link); link.click(); link.remove();
      setTimeout(() => { URL.revokeObjectURL(url); this.urls.delete(url); }, 60000);
      return {};
    }
    async call(method, args) {
      switch (method) {
        case 'snapshot': return this.snapshot();
        case 'interface_locale': {
          if (Object.prototype.hasOwnProperty.call(args, 'locale')) {
            if (!['system', 'zh', 'en'].includes(args.locale)) throw new Error('Invalid interface language.');
            this.interfaceLocale = args.locale;
            try { this.storage.setItem('teno.web.interface-locale', args.locale); } catch (_) {}
          }
          let locale = this.interfaceLocale;
          if (!locale) { try { locale = this.storage.getItem('teno.web.interface-locale'); } catch (_) {} }
          if (typeof document !== 'undefined') { const lang = locale && locale !== 'system' ? locale : (navigator.language.startsWith('zh') ? 'zh' : 'en'); document.documentElement.lang = lang === 'zh' ? 'zh-Hans' : 'en'; }
          return {locale: ['system', 'zh', 'en'].includes(locale) ? locale : 'system'};
        }
        case 'login': return this.login(args);
        case 'logout': return this.logout();
        case 'request': return this.request(args);
        case 'preferences': return {personal_core: true, settings: this.settings};
        case 'cache_preferences': this.settings = args; return {};
        case 'recording_cache': return this.recordingCache(args);
        case 'pending_imports': return {items: []};
        case 'import': return this.pick(args);
        case 'retryUpload': return this.retryUpload(args);
        case 'deleteLocal': return this.deleteLocal(args);
        case 'cancelUpload': this.uploads.get(args.id)?.abort(); return {};
        case 'playback': return this.playback(args);
        case 'history': {
          this.check(this.epoch); const key = `teno.web.history.${this.session.id}`;
          let items = []; try { items = JSON.parse(this.storage.getItem(key) || '[]'); } catch (_) {}
          if (args.clear) items = [];
          if (args.query) items = [args.query, ...items.filter(q => q !== args.query)].slice(0, 12);
          try { this.storage.setItem(key, JSON.stringify(items)); } catch (_) {}
          return {items};
        }
        case 'storage': await this.loadDrafts(); return {local_bytes: this.drafts.reduce((n, d) => n + d.size, 0), cache_bytes: await this.readCache.size(this.session?.id)};
        case 'clear_cache': await this.invalidateCache(); this.resetPlayer(); this.emit(); return {bytes: 0};
        case 'export': case 'preview': return this.download(args);
        case 'local_export': return this.download(args, true);
        case 'shareText':
          if (navigator.share) { try { await navigator.share({text: args.text}); return {}; } catch (e) { if (e.name === 'AbortError') return {}; } }
          await navigator.clipboard.writeText(args.text); return {};
        default: throw new Error('This action is not available in the Web preview.');
      }
    }
  }
  if (typeof module !== 'undefined') module.exports = {TenoWebRuntime, BrowserStore, RecordingCache, fileInfo};
  if (typeof document !== 'undefined') {
    const runtime = new TenoWebRuntime(); runtime.playSequence = 0;
    globalThis.tenoWeb = {listen: fn => runtime.listen(fn), call: async (method, args) => {
      try { return JSON.stringify(await runtime.call(method, JSON.parse(args))); }
      catch (e) { throw new Error(e.message || 'The action could not be completed.'); }
    }};
    addEventListener('beforeunload', e => { if (runtime.uploads.size) { e.preventDefault(); e.returnValue = ''; } });
  }
})();
