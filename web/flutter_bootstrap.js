{{flutter_js}}
{{flutter_build_config}}

// Release builds load their assets (fonts, icon font, manifests) from a
// per-release path, /v/<commit>/assets/..., which vercel.json maps back to
// /assets/ and caches forever. Flutter's asset file names never change
// between releases, so without this a browser could pair a new app with
// last release's cached icon font and show blank icons.
// scripts/build.sh replaces the token below; local runs keep the default.
const frAssetVersion = '__FR_ASSET_VERSION__';

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  config: frAssetVersion.indexOf('__FR') === 0
    ? {}
    : { assetBase: '/v/' + frAssetVersion + '/' },
});
