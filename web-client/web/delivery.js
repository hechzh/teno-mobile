/* Public code/font delivery only. API, sessions and imported files stay on origin. */
(() => {
  'use strict';
  const meta = name => document.querySelector(`meta[name="${name}"]`)?.content || '';
  const origin = new URL(meta('teno-assets') || './', document.baseURI);
  const expected = meta('teno-main-sha');
  const alternatives = meta('teno-cdn').split(',').filter(Boolean).map(v => new URL(v));
  let selected = origin, source = 'origin', ready;
  async function fetchTimed(url, timeout) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeout);
    try {
      const response = await fetch(url, {credentials: 'omit', signal: controller.signal, referrerPolicy: 'no-referrer'});
      if (!response.ok) throw new Error('asset-http-error');
      // Keep the timer active for the whole body, not just response headers.
      return await response.arrayBuffer();
    } finally { clearTimeout(timer); }
  }
  async function select() {
    if (new URL(location.href).searchParams.get('teno_assets') !== 'origin' && expected && alternatives.length) {
      try {
        selected = await Promise.any(alternatives.map(async base => {
          const bytes = await fetchTimed(new URL('asset-proof.json', base), 5000);
          if (JSON.parse(new TextDecoder().decode(bytes)).main !== expected) throw new Error('asset-version-mismatch');
          return base;
        }));
        source = selected.host;
      } catch (_) { /* A blocked CDN cannot trap startup; original assets remain available. */ }
    }
    return selected;
  }
  async function bytes(relative) {
    // Callers cannot turn this into a cross-origin data request.
    if (!/^assets\/fonts\/subsets\/[a-z0-9.-]+\.(woff2|json)$/.test(relative)) throw new Error('invalid-font-asset');
    await (ready ??= select());
    try { return new Uint8Array(await fetchTimed(new URL('assets/'+relative, selected), 12000)); }
    catch (error) {
      if (selected.href === origin.href) throw error;
      return new Uint8Array(await fetchTimed(new URL('assets/'+relative, origin), 12000));
    }
  }
  function script(url) {
    return new Promise((resolve, reject) => {
      const node = document.createElement('script');
      let settled = false;
      const finish = (error) => {
        if (settled) return;
        settled = true; clearTimeout(timer); node.onload = node.onerror = null;
        if (error) { node.remove(); reject(error); } else resolve();
      };
      const timer = setTimeout(() => finish(new Error('page-load-timeout')), 12000);
      node.src = url.href; node.crossOrigin = 'anonymous'; node.referrerPolicy = 'no-referrer';
      node.onload = () => finish(); node.onerror = () => finish(new Error('page-load-failed'));
      document.head.appendChild(node);
    });
  }
  let pageMap;
  const pageLoads = new Map();
  async function getPageMap() {
    try { return JSON.parse(new TextDecoder().decode(await fetchTimed(new URL('page-bundles.json', selected), 5000))).parts || {}; }
    catch (error) {
      if (selected.href === origin.href) throw error;
      return JSON.parse(new TextDecoder().decode(await fetchTimed(new URL('page-bundles.json', origin), 5000))).parts || {};
    }
  }
  async function loadPage(name) {
    let parts;
    try { parts = await (pageMap ??= getPageMap()); }
    catch (error) { pageMap = null; throw error; }
    const target = parts[name] || name;
    if (target !== name && !/^pages-(shared|route-\d+)\.part\.js$/.test(target)) throw new Error('invalid-page-bundle');
    if (!pageLoads.has(target)) {
      const pending = script(new URL(target, selected)).catch(error => {
        if (selected.href === origin.href) throw error;
        return script(new URL(target, origin));
      }).catch(error => { pageLoads.delete(target); throw error; });
      pageLoads.set(target, pending);
    }
    return pageLoads.get(target);
  }
  // The pinned Dart SDK exposes this hook for deferred JS modules. No eval/blob code.
  globalThis.dartDeferredLibraryLoader = (uri, success, failure) => {
    const url = new URL(uri, selected);
    const name = url.pathname.split('/').pop();
    if (!/^main\.dart\.js_[A-Za-z0-9_.-]+\.part\.js$/.test(name)) { failure('invalid-page-asset'); return; }
    loadPage(name).then(success, () => failure('page-load-failed'));
  };
  globalThis.tenoAssets = {
    select: () => ready ??= select(), bytes,
    get source() { return source; }, get base() { return selected.href; },
    listenInput(listener) {
      document.addEventListener('input', event => {
        // Flutter's editor lives in a shadow root; event.target may be the host.
        const field = event.composedPath?.()[0] || event.target;
        const editor = field?.classList?.contains('flt-text-editing') || field?.getAttribute?.('data-semantics-role') === 'text-field';
        if (editor && field.type !== 'password') listener(field.value || '');
      }, true);
    },
    isResource(value) {
      try {
        const url = new URL(value);
        return [origin, ...alternatives].some(base => base.origin === url.origin && url.pathname.startsWith(base.pathname));
      } catch (_) { return false; }
    }
  };
})();
