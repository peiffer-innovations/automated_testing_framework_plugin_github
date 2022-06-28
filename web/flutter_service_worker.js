'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';
const RESOURCES = {
  "favicon.png": "7d2009652f165b0bc9d9e23452621c35",
"canvaskit/canvaskit.js": "c2b4e5f3d7a3d82aed024e7249a78487",
"canvaskit/profiling/canvaskit.js": "ae2949af4efc61d28a4a80fffa1db900",
"canvaskit/profiling/canvaskit.wasm": "95e736ab31147d1b2c7b25f11d4c32cd",
"canvaskit/canvaskit.wasm": "4b83d89d9fecbea8ca46f2f760c5a9ba",
"index.html": "979598ad7970bd0881cbfc010eb9984f",
"/": "979598ad7970bd0881cbfc010eb9984f",
"flutter.js": "eb2682e33f25cd8f1fc59011497c35f8",
"icons/Icon-512.png": "fcc99bfdc6a50774538d60bb93a26b0f",
"icons/Icon-192.png": "c8302094bb862f810767070975583892",
"manifest.json": "15f73b7e8a8209c2206210b3ac8dea1b",
"version.json": "4b6db237b3514a88107a422469adfb0f",
"assets/FontManifest.json": "3a1c01ebd9adb7aecf384a895a3cbb43",
"assets/fonts/MaterialIcons-Regular.otf": "132a5e63b5e510933ab4845577716106",
"assets/AssetManifest.json": "68c85d7714e3b6e58070b7d2aa8853e7",
"assets/assets-src/MaterialIcons-Regular.ttf": "a37b0c01c0baf1888ca812cc0508f6e2",
"assets/packages/automated_testing_framework_example/assets/all_tests.json": "2d2c55430cb923f834f1683ae76deaf4",
"assets/packages/automated_testing_framework_example/assets/tests/slidables.json": "0e6ecffce2e4fe788c9f7a00e1a7d4e7",
"assets/packages/automated_testing_framework_example/assets/tests/variables.json": "7d554f244b740f375961fb0c9f80b393",
"assets/packages/automated_testing_framework_example/assets/tests/interpolated_variables.json": "2491e0da34265345c86a6fe89a089894",
"assets/packages/automated_testing_framework_example/assets/tests/failure.json": "8cefd140b688b564169ed2d304a52ce8",
"assets/packages/automated_testing_framework_example/assets/tests/double_tap.json": "35a920944da4cf2e2154bf1c138c2e34",
"assets/packages/automated_testing_framework_example/assets/tests/dropdowns.json": "f1f2f78f6bbb729048728e05abca6d41",
"assets/packages/automated_testing_framework_example/assets/tests/icons_gesture.json": "655cf20202457e9a9b8692f05334fbc8",
"assets/packages/automated_testing_framework_example/assets/tests/buttons.json": "d35cccfbd9c0c4547e34441f6038ac5c",
"assets/packages/automated_testing_framework_example/assets/tests/stacked_scrolling.json": "a98582489811cc6fc6a56cfcd5835699",
"assets/packages/automated_testing_framework_example/assets/tests/theme.json": "5b72a996ff15d64d58b7627f29df05bb",
"assets/packages/automated_testing_framework_example/assets/tests/screenshot.json": "5a070f35d91e2c1cde99395809a1d876",
"assets/packages/automated_testing_framework_example/assets/tests/accessibility.json": "c98acf550ea22677d4adfa3016b120f8",
"assets/packages/automated_testing_framework_example/assets/tests/exit_app.json": "358f6cab447478d73eea4127678106ac",
"assets/packages/automated_testing_framework_example/assets/tests/issue_5.json": "21c374a01729bf635c57bc9effc9d37b",
"assets/NOTICES": "1a2e5011e94000d2e56dec15feb3243f",
"main.dart.js": "afb54c4fbef8cf44f924a7990272aec6"
};

// The application shell files that are downloaded before a service worker can
// start.
const CORE = [
  "main.dart.js",
"index.html",
"assets/NOTICES",
"assets/AssetManifest.json",
"assets/FontManifest.json"];
// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});

// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});

// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache.
        return response || fetch(event.request).then((response) => {
          cache.put(event.request, response.clone());
          return response;
        });
      })
    })
  );
});

self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});

// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}

// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
