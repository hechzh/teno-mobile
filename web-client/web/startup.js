/* Startup-only diagnostics: no account data, API payloads, or persistent storage writes. */
(() => {
  'use strict';
  const root = document.getElementById('loading');
  if (!root) return;
  let language = (navigator.language || '').startsWith('zh') ? 'zh' : 'en';
  try { const saved = localStorage.getItem('teno.web.interface-locale'); if (saved === 'zh' || saved === 'en') language = saved; } catch (_) {}
  const zh = language === 'zh';
  document.documentElement.lang = zh ? 'zh-Hans' : 'en';
  const words = zh ? {
    download: '正在下载应用…', engine: '正在准备显示组件与字体…', interface: '正在打开界面…',
    first: '首次打开需要下载应用，请保持页面打开。', slow: '加载时间较长，可以继续等待，或切换网络后重新加载。',
    timeout: '加载尚未完成', offline: '网络已断开', error: '应用未能启动',
    failed: '请重新加载。若仍失败，可复制诊断信息协助排查。',
    offlineHint: '请连接网络后重新加载。', retry: '重新加载', compatible: '尝试兼容模式',
    copy: '复制诊断信息', copied: '已复制', manual: '请复制下方诊断信息',
    privacy: '诊断仅包含启动阶段和资源加载情况，不含账号或录音内容。'
  } : {
    download: 'Downloading the app…', engine: 'Preparing display components and fonts…', interface: 'Opening the app…',
    first: 'The first visit downloads the app. Please keep this page open.', slow: 'Loading is taking longer. You can keep waiting, or change networks and reload.',
    timeout: 'Loading has not finished', offline: 'You are offline', error: 'Teno could not start',
    failed: 'Reload to try again. If it fails again, copy the diagnostics for support.',
    offlineHint: 'Reconnect to the internet, then reload.', retry: 'Reload', compatible: 'Try compatibility mode',
    copy: 'Copy diagnostics', copied: 'Copied', manual: 'Copy the diagnostics below',
    privacy: 'Diagnostics contain startup stages and resource timings, without account or recording content.'
  };
  const el = id => document.getElementById('loading-' + id);
  const start = performance.now();
  const trace = [];
  let current = 'download', done = false, terminal = false, reason = '';
  const assetPath = document.querySelector('meta[name="teno-assets"]')?.content || './';
  const base = new URL(assetPath, document.baseURI);
  // Only paths inside this app's static bundle may appear in diagnostics.
  function resourcePath(value) {
    try { const url = new URL(value, document.baseURI); return url.origin === location.origin &&
      (url.pathname.startsWith(base.pathname) || url.pathname.startsWith(new URL(document.baseURI).pathname)) &&
      /\.(?:js|wasm|json|ttf|otf|woff2?)$/.test(url.pathname) ? url.pathname : ''; } catch (_) { return ''; }
  }
  function record(stage) { trace.push({stage, ms: Math.round(performance.now() - start)}); }
  function showActions() { el('actions').hidden = false; el('compatible').hidden = current === 'download'; }
  function status(kind) { el('status').textContent = words[kind]; }
  function fail(code, path = '') {
    if (done) return;
    terminal = true; reason = code; record(code);
    status(navigator.onLine === false ? 'offline' : 'error');
    el('hint').textContent = navigator.onLine === false ? words.offlineHint : words.failed;
    if (path) reason += ': ' + path;
    root.setAttribute('aria-busy', 'false'); showActions();
  }
  function stage(next) {
    if (done) return;
    current = next; record(next);
    if (!terminal) { status(next); el('hint').textContent = words.first; }
    if (!el('actions').hidden) showActions();
  }
  const slowTimer = setTimeout(() => { if (!done && !terminal) { el('hint').textContent = words.slow; showActions(); } }, 15000);
  const timeoutTimer = setTimeout(() => {
    if (done || terminal) return;
    reason = 'startup-timeout'; record(reason); status('timeout'); el('hint').textContent = words.slow; showActions();
  }, 45000);
  function ready() {
    if (done) return;
    done = true; record('ready'); clearTimeout(slowTimer); clearTimeout(timeoutTimer);
    root.remove();
  }
  function diagnostics() {
    return JSON.stringify({app: 'Teno', bundle: base.pathname, stage: current, reason,
      elapsedMs: Math.round(performance.now() - start), online: navigator.onLine,
      compatibilityMode: new URL(location.href).searchParams.get('teno_render') === 'cpu', stages: trace,
      resources: performance.getEntriesByType('resource').filter(e => resourcePath(e.name)).map(e => ({
        path: resourcePath(e.name), ms: Math.round(e.duration), bytes: e.encodedBodySize,
        transferred: e.transferSize, status: e.responseStatus || undefined
      })).slice(-30)}, null, 2);
  }
  el('retry').textContent = words.retry;
  el('compatible').textContent = words.compatible;
  el('copy').textContent = words.copy;
  el('retry').addEventListener('click', () => location.reload());
  el('compatible').addEventListener('click', () => {
    const url = new URL(location.href); url.searchParams.set('teno_render', 'cpu'); location.replace(url.href);
  });
  el('copy').addEventListener('click', async () => {
    const text = diagnostics(); el('hint').textContent = words.privacy;
    try { await navigator.clipboard.writeText(text); el('copy').textContent = words.copied; }
    catch (_) { const box = el('diagnostics'); box.value = text; box.hidden = false; box.focus(); box.select(); el('copy').textContent = words.manual; }
  });
  addEventListener('error', event => {
    if (done) return;
    const path = resourcePath(event.target?.src || event.filename);
    fail(event.target?.src ? 'resource-error' : 'script-error', path);
  }, true);
  addEventListener('unhandledrejection', () => fail('initialization-error'));
  addEventListener('offline', () => { if (!done) { status('offline'); el('hint').textContent = words.offlineHint; showActions(); } });
  addEventListener('online', () => { if (!done && !terminal) { status(current); el('hint').textContent = words.slow; } });
  addEventListener('flutter-first-frame', ready, {once: true});
  globalThis.tenoStartup = {stage, fail, ready, diagnostics};
  stage('download');
  if (navigator.onLine === false) { status('offline'); el('hint').textContent = words.offlineHint; showActions(); }
})();
