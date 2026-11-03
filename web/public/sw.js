// Serves the app without a connection. Pages are fetched fresh when online and
// kept for later; when the network fails, a kept page stands in. The notes
// themselves come from the app's own store (IndexedDB), not from here.
//
// Moving between pages fetches a payload the browser can't keep usefully, so
// those requests go to the network, given up on when it doesn't answer. When
// one fails, Next.js falls back to loading the page itself, which this worker
// answers.

const VERSION = "v1";
const STATIC_CACHE = `anchor-static-${VERSION}`;
const PAGE_CACHE = `anchor-pages-${VERSION}`;

// The app's pages. A note's page serves every note: it reads the note's id
// from the address.
const SHELL = ["/notes", "/notes/new", "/archive", "/trash", "/settings"];

const shellPath = (pathname) => {
  const path = pathname.replace(/\/+$/, "") || "/";
  if (SHELL.includes(path)) return path;
  if (path.startsWith("/notes/")) return "/notes/new";
  return null;
};

const isStatic = (url) =>
  url.pathname.startsWith("/_next/static/") ||
  /\.(?:png|svg|ico|webmanifest|woff2?|ttf)$/.test(url.pathname);

async function keepPage(path, response) {
  const cache = await caches.open(PAGE_CACHE);
  await cache.put(path, response.clone());
  // The scripts and styles the page needs, so it also runs offline.
  const html = await response.text();
  const assets = new Set(
    Array.from(html.matchAll(/\/_next\/static\/[^"'\s)\\]+/g), (m) => m[0]),
  );
  const statics = await caches.open(STATIC_CACHE);
  await Promise.all(
    Array.from(assets, async (asset) => {
      if (!(await statics.match(asset)))
        await statics.add(asset).catch(() => {});
    }),
  );
}

/**
 * Every static file of the build, listed by scripts/sw-manifest.mjs, and none
 * of an older build's. Checked again as pages load, since a new deployment
 * doesn't change this worker.
 */
let keptManifest = null;
async function keepBuild() {
  const response = await fetch("/_next/static/sw-manifest.json", {
    cache: "no-store",
  });
  if (!response.ok) return;
  const text = await response.text();
  if (text === keptManifest) return;
  const files = JSON.parse(text);
  const statics = await caches.open(STATIC_CACHE);
  await Promise.all(
    files.map(async (file) => {
      if (!(await statics.match(file))) await statics.add(file).catch(() => {});
    }),
  );
  const current = new Set(files);
  for (const request of await statics.keys()) {
    const { pathname } = new URL(request.url);
    if (pathname.startsWith("/_next/static/") && !current.has(pathname))
      await statics.delete(request);
  }
  keptManifest = text;
}

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      await keepBuild().catch(() => {});
      for (const path of SHELL) {
        try {
          const response = await fetch(path, { credentials: "same-origin" });
          if (response.ok && !response.redirected)
            await keepPage(path, response);
        } catch {
          // Offline while installing: pages are kept as they are visited.
        }
      }
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      for (const name of await caches.keys())
        if (name !== STATIC_CACHE && name !== PAGE_CACHE)
          await caches.delete(name);
      await self.clients.claim();
    })(),
  );
});

async function fromCacheFirst(request) {
  const cache = await caches.open(STATIC_CACHE);
  const kept = await cache.match(request);
  if (kept) return kept;
  const response = await fetch(request);
  if (response.ok && response.type === "basic")
    await cache.put(request, response.clone());
  return response;
}

// A server that takes the connection but doesn't answer would hold the page
// up until the browser gives up; after this long a kept page stands in.
const PAGE_WAIT_MS = 5000;
// A request given up on is cut off after this, so it doesn't hold one of the
// browser's few connections to the server.
const GIVE_UP_MS = 30000;
// Once the server hasn't answered, pages come from what is kept straight
// away, without waiting again, until it answers.
const RECHECK_MS = 3000;
let unreachable = false;

function fetchWithin(request, ms) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), ms);
  return fetch(request, { signal: controller.signal }).then(
    (response) => {
      clearTimeout(timer);
      unreachable = false;
      return response;
    },
    (error) => {
      clearTimeout(timer);
      unreachable = true;
      throw error;
    },
  );
}

// Asks the server whether it is back, at most every few seconds.
let checking = null;
function recheck() {
  checking ??= fetchWithin(new Request("/api/health"), RECHECK_MS)
    .catch(() => {})
    .finally(() => {
      checking = null;
    });
  return checking;
}

async function page(event, url) {
  const { request } = event;
  const path = shellPath(url.pathname);
  const network = fetchWithin(request, GIVE_UP_MS);
  // Kept for next time, also when a kept page answered first. This runs
  // before the page takes the response's body.
  event.waitUntil(
    network
      .then((response) => {
        if (
          path &&
          response.ok &&
          !response.redirected &&
          response.type === "basic"
        )
          return Promise.all([keepPage(path, response.clone()), keepBuild()]);
      })
      .catch(() => {}),
  );
  const kept = async () => {
    const cache = await caches.open(PAGE_CACHE);
    return (path && (await cache.match(path))) || (await cache.match("/notes"));
  };
  let timer;
  const slow = new Promise((resolve) => {
    timer = setTimeout(resolve, unreachable ? 0 : PAGE_WAIT_MS);
  });
  try {
    const response = await Promise.race([network, slow]);
    if (response) return response;
    unreachable = true;
    return (await kept()) ?? (await network);
  } catch (error) {
    const copy = await kept();
    if (copy) return copy;
    throw error;
  } finally {
    clearTimeout(timer);
  }
}

// Moving between pages: a server that doesn't answer fails like a missing
// connection, so Next.js loads the page itself and a kept one stands in. Once
// it hasn't answered, that happens at once while it is asked again.
async function payload(event) {
  if (unreachable) {
    event.waitUntil(recheck());
    return Response.error();
  }
  let timer;
  const slow = new Promise((resolve) => {
    timer = setTimeout(() => {
      unreachable = true;
      resolve(Response.error());
    }, PAGE_WAIT_MS);
  });
  try {
    return await Promise.race([
      fetchWithin(event.request, GIVE_UP_MS).catch(() => Response.error()),
      slow,
    ]);
  } finally {
    clearTimeout(timer);
  }
}

self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;
  if (url.pathname.startsWith("/api/") || url.pathname.startsWith("/uploads/"))
    return;
  if (isStatic(url)) {
    event.respondWith(fromCacheFirst(request));
    return;
  }
  if (request.mode === "navigate") event.respondWith(page(event, url));
  else if (request.headers.get("RSC") === "1")
    event.respondWith(payload(event));
});
