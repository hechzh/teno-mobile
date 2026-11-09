{{flutter_js}}
{{flutter_build_config}}
const bundle = new URL(document.querySelector('meta[name="teno-assets"]')?.content || './', document.baseURI);
const config = {
    entrypointBaseUrl: bundle.href,
    assetBase: bundle.href,
    canvasKitBaseUrl: new URL('canvaskit/', bundle).href,
    canvasKitForceCpuOnly: new URL(location.href).searchParams.get('teno_render') === 'cpu',
};
_flutter.loader.load({
  config,
  onEntrypointLoaded: async function(engineInitializer) {
    try {
      globalThis.tenoStartup?.stage('engine');
      const appRunner = await engineInitializer.initializeEngine(config);
      globalThis.tenoStartup?.stage('interface');
      await appRunner.runApp();
    } catch (_) { globalThis.tenoStartup?.fail('engine-or-interface-error'); }
  }
}).catch(() => globalThis.tenoStartup?.fail('loader-error'));
