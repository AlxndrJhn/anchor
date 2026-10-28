// Points the app's /api requests at the backend in the browser, for the
// builds served without a server (see ./mode).

import { setAccessToken, setRefreshToken } from "@/features/auth/store";
import { welcome } from "@/lib/demo/demos";
import { buildData } from "@/lib/demo/seed";
import { browserStorage, memoryStorage } from "./db";
import { basePath, isDemo, isServerless } from "./mode";
import { LocalServer } from "./server";

let server: LocalServer | null = null;

/** The backend in the browser; only in the serverless builds. */
export function localServer(): LocalServer {
  server ??= new LocalServer(
    isDemo ? memoryStorage(() => buildData(welcome)) : browserStorage(),
  );
  return server;
}

function isApiRequest(url: URL) {
  return url.origin === window.location.origin && /\/api\//.test(url.pathname);
}

// A static build has one note page, /notes/new, and it reads the note's id
// from the address. What Next.js fetches to open /notes/<id> (the page's
// payloads, and a check that it exists) is taken from that page.
const notePayload = new RegExp(
  `^${basePath}/notes/(?!new(?:[./]|$))[^/.]+(?=\\.txt$|/__next|$)`,
);

function payloadUrl(url: URL): string | null {
  if (url.origin !== window.location.origin || !notePayload.test(url.pathname))
    return null;
  return url.href.replace(
    url.pathname,
    url.pathname.replace(notePayload, `${basePath}/notes/new`),
  );
}

let installed = false;

export function installLocalBackend() {
  if (!isServerless || installed || typeof window === "undefined") return;
  installed = true;
  const networkFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    const url = new URL(
      input instanceof Request ? input.url : String(input),
      window.location.href,
    );
    const payload = payloadUrl(url);
    if (payload)
      return networkFetch(new Request(payload, new Request(input, init)));
    if (!isApiRequest(url)) return networkFetch(input, init);
    // Nothing else changes the notes, so there is nothing to push.
    if (url.pathname.endsWith("/api/sync/events"))
      return Promise.resolve(new Response(null, { status: 404 }));
    return localServer().handle(new Request(input, init));
  };
  // Signed in from the start: this browser holds one person's notes.
  setAccessToken("local");
  setRefreshToken("local");
}
