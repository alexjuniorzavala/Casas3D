const CACHE_NAME = "casas3d-media-cache-v3";
const THREE_DAYS_MS = 3 * 24 * 60 * 60 * 1000;
const VIDEO_CACHE_TTL_MS = THREE_DAYS_MS;
const IMAGE_CACHE_TTL_MS = THREE_DAYS_MS;
const META_KEY = "/__casas3d_media_cache_meta__";

async function getCacheMeta(cache) {
    try {
        const response = await cache.match(META_KEY);
        if (!response) {
            return { updatedAt: 0 };
        }

        const data = await response.json();
        return {
            updatedAt: Number(data.updatedAt || 0)
        };
    } catch (error) {
        return { updatedAt: 0 };
    }
}

async function setCacheMeta(cache, updatedAt) {
    const metaResponse = new Response(JSON.stringify({ updatedAt }), {
        headers: {
            "Content-Type": "application/json"
        }
    });

    await cache.put(META_KEY, metaResponse);
}

self.addEventListener("install", function (event) {
    self.skipWaiting();
    event.waitUntil(caches.open(CACHE_NAME));
});

self.addEventListener("activate", function (event) {
    event.waitUntil(
        caches.keys().then(function (cacheNames) {
            return Promise.all(
                cacheNames
                    .filter(function (cacheName) {
                        return cacheName !== CACHE_NAME;
                    })
                    .map(function (cacheName) {
                        return caches.delete(cacheName);
                    })
            );
        }).then(function () {
            return self.clients.claim();
        })
    );
});

self.addEventListener("fetch", function (event) {
    const request = event.request;

    if (request.method !== "GET") {
        return;
    }

    const url = new URL(request.url);
    const isVideoRequest = /\.(mp4|webm|mov|m4v)(\?.*)?$/i.test(url.pathname);
    const isImageRequest = /\.(jpg|jpeg|png|gif|webp|bmp|svg)(\?.*)?$/i.test(url.pathname);
    const isAllowedOrigin =
        url.origin === self.location.origin ||
        url.origin === "https://i.ytimg.com" ||
        url.origin === "https://img.youtube.com";

    if ((!isVideoRequest && !isImageRequest) || !isAllowedOrigin) {
        return;
    }

    const ttl = isImageRequest ? IMAGE_CACHE_TTL_MS : VIDEO_CACHE_TTL_MS;

    event.respondWith(
        caches.open(CACHE_NAME).then(async function (cache) {
            const cachedResponse = await cache.match(request);
            const meta = await getCacheMeta(cache);
            const now = Date.now();

            if (cachedResponse && now - meta.updatedAt < ttl) {
                return cachedResponse;
            }

            try {
                const networkResponse = await fetch(request, { cache: "no-store" });

                if (networkResponse && networkResponse.status === 200) {
                    cache.put(request, networkResponse.clone());
                    await setCacheMeta(cache, now);
                }

                return networkResponse;
            } catch (error) {
                if (cachedResponse) {
                    return cachedResponse;
                }

                throw error;
            }
        })
    );
});
