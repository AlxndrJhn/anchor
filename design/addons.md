# Addons for Anchor+ — design

Status: phase 1 (themes and CSS) is built; the rest is a proposal. Scope chosen: restyling, note commands, UI panels
and server hooks; on web, desktop and Android; installed per user, by the
admin, or from a catalog.

## What exists today

- Colour schemes (`design/schemes/schemes.json`) and a custom theme
  (`web/lib/design/custom-theme.ts`, `mobile/lib/core/theme/custom_theme.dart`).
  Both are kept **on the device only**; no preferences reach the server.
- Note content is Quill Delta JSON. The server already converts it to and
  from markdown (`server/src/import-export/markdown/`).
- Every server-side note change, whether from `NotesService.update` or from a
  sync push (`sync-apply.service.ts`), goes through `SyncEmitterService`.
  That makes it the one place to fire hooks.
- The web app has no CSP, and nothing in the app runs third-party code yet.
  Android has no WebView or JS engine.

## The addon package

An addon is a folder or a `.zip` file:

```
my-addon/
  addon.json        manifest
  style.css         optional: restyle (web, desktop)
  main.js           optional: commands, badges (runs sandboxed)
  panel.html        optional: a panel (runs sandboxed)
```

```jsonc
{
  "id": "dev.example.sort-list",      // reverse-DNS, unique
  "name": "Sort list",
  "version": "1.2.0",
  "anchorApi": 1,                     // the addon API version it targets
  "platforms": ["web", "android"],
  "permissions": ["notes:read", "notes:write"],
  "contributes": {
    "styles": ["style.css"],
    "theme": { "light": { "accent": "#5E81AC" }, "dark": { } }, // schemes.json keys
    "commands": [{ "id": "sort", "title": "Sort list A–Z", "where": ["note-menu", "slash"] }],
    "panels": [{ "id": "stats", "title": "Stats", "slot": "note-side", "entry": "panel.html" }],
    "badges": true,
    "hooks": [{ "on": ["note.updated"], "url": "https://…", "secret": "per-install" }]
  }
}
```

## The four kinds of addon

| Kind | Web, desktop | Android | How it runs |
|---|---|---|---|
| **Theme tokens** | ✓ | ✓ | Declarative: the same keys as `schemes.json`, applied like the custom theme |
| **CSS** | ✓ | — | One `<style>` after the app's own, unlayered, so it wins at equal specificity; `?safe` leaves it out |
| **Commands, badges** | ✓ | ✓ (phase 4) | `main.js` in a sandbox, talking to the app over an RPC API |
| **Panels** | ✓ | ✓ (phase 5) | `panel.html` in a sandboxed frame at a fixed slot |
| **Server hooks** | ✓ (every client) | ✓ | Signed webhooks sent by the server; no addon code runs on the server |

Flutter can't apply CSS, so on Android a restyle is limited to theme tokens.
The README and the install dialog will say so.

### Sandbox and API (commands, badges, panels)

- **Web:** an `<iframe sandbox="allow-scripts">` without `allow-same-origin`.
  It has an opaque origin, so it cannot reach cookies, storage, the DOM or
  the API token, and the app only answers `postMessage` RPC.
- **Android:** a headless `webview_flutter` WebView (a new dependency) loads
  the **same** `main.js` and speaks the same RPC over a JavaScript channel. One
  addon then works on both platforms.
- **Desktop:** gets the web behaviour for free, since its windows are already
  sandboxed.
- **API v1** (`anchor.*`), each call checked against the declared permissions:
  - `commands.register(id, fn)`: `fn` receives the open note or the selected notes.
  - `notes.get / list / update / create`. Content is **markdown** in and
    out, which spares addon authors Quill Delta. The delta⇄markdown converter
    moves from `server/` into a package shared with `web/`, with a Dart port
    for Android.
  - `badges.provide(note => ({ text, colour }) | null)`: declarative and cheap,
    with no frame per card.
  - `storage.get/set`: per-addon and per-user, synced.
  - `net.fetch(url)`: only to hosts listed in a `network:<host>` permission.
  - `ui.toast`, `ui.confirm`.
- Writes go through the normal save path (save queue and outbox on web,
  `NotesRepository.updateNote` on Android), so frozen notes, revisions and
  undo keep working.
- A CSP is added to the web app at the same time (`frame-src` for the sandbox
  only) to close the XSS gap before third-party code arrives.

### Server hooks

- `SyncEmitterService.emit` also queues a row in a new `HookDelivery`
  table, in the same transaction, for each matching hook. A `@Cron`
  worker POSTs the event with an HMAC-SHA256 signature
  (`X-Anchor-Signature`) and retries with backoff.
- Events: `note.created|updated|trashed|deleted`, `tag.*`, `reminder.due`.
  The payload carries the note as markdown, its tags and its ids.
- To act on a note, a hook uses the existing API with an **API token scoped
  to that addon**. No arbitrary code runs on the server; server-side scripting
  can be reconsidered later.

## Storage, sync, install

- Prisma: `UserAddon` holds the userId, the manifest's id, version, manifest,
  files (as text), and enabled. Later phases add `Addon` for admin and catalog
  addons, and `HookDelivery` for the hook queue.
- Addons are **not** in the sync feed. A new `SyncEntityType` value would
  break switching a server back to upstream Anchor, whose server can't read
  change-log rows of a kind it doesn't know. Instead, the apps fetch
  `GET /api/addons` when they start, when they come back to the foreground,
  and (on the web) when the window gets focus. Addons change rarely, so this
  is enough. The apps keep the last list, so the first paint already has
  the addons' colours.
- On an **upstream Anchor server**, which has no `api/addons`, Settings ›
  Addons says so. Keeping addons on the device alone was left out of
  phase 1.
- **Per user:** Settings › Addons › Install, by uploading a zip or pasting a
  URL. The install dialog lists the permissions requested.
- **Admin:** a folder (`/data/addons`) loaded at start-up, plus Admin ›
  Addons to:
  - force an addon on or off
  - turn off user installs
  - turn off the catalog
- **Catalog:** an `index.json` in a GitHub repo (`AlxndrJhn/anchor-addons`)
  lists each addon's id, version, zip URL and sha256. Clients check the hash.
  Updates need a new approval when the permissions change.
- **Safe mode:** `?safe` on web, or holding a button at Android launch,
  starts with every addon off.

## Phases (each one is a PR that can ship on its own)

1. **Foundation and restyling** (built). The manifest, Settings › Addons,
   install from a zip or URL, theme tokens (web and Android), CSS (web),
   server storage and fetching, and safe mode (`?safe`). Android lists the
   addons and turns them on or off, but installs nothing itself. The serverless
   builds keep addons in the browser. The manifest checker is in
   `web/lib/addons/manifest.ts`, with a twin in
   `server/src/addons/addon-manifest.ts`.
2. **Note commands on web.** The sandbox iframe, RPC and API v1 (notes,
   commands, storage, toasts), the shared markdown converter, the note menu
   and slash menu, and the CSP.
3. **Server hooks.** `HookDelivery`, the signed webhooks, scoped tokens and
   the delivery log in Settings.
4. **Commands on Android.** The WebView runtime, the Dart markdown converter
   and the menu integration.
5. **Panels and badges.** Web first, then Android.
6. **Admin addons and the catalog.** The folder, Admin › Addons, the
   catalog repo and updates.

Each phase also brings an example addon (e.g. a Solarized theme, "Sort list",
a word-count badge, a webhook to ntfy) and a section in the README table.
