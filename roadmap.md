# Anchor+ roadmap

What's planned for Anchor+, and where each piece stands. Every phase is a PR
that can ship on its own.

## Addons

Let people restyle Anchor+ and add to it: on the web, desktop and Android,
installed by each person, by the admin, or from a catalog. The design is in
[design/addons.md](design/addons.md).

| Phase | What it brings | Platforms | Status |
|---|---|---|---|
| 1. Foundation and restyling | `addon.json` manifest, Settings › Addons, install from a .zip or an address, theme colours, CSS, storage on the server, safe mode (`?safe`) | Web, desktop; Android applies colours and turns addons on or off | Built |
| 2. Note commands on web | Sandboxed addon code, the `anchor.*` API (notes as markdown, commands, storage, toasts), note menu and slash menu entries, a CSP | Web, desktop | Planned |
| 3. Server hooks | Signed webhooks on note and tag changes and due reminders, API tokens scoped to an addon, a delivery log in Settings | Server, every app | Planned |
| 4. Commands on Android | The same addon code in a WebView, a Dart markdown converter, menu entries | Android | Planned |
| 5. Panels and badges | Addon panels beside a note, badges on note cards | Web first, then Android | Planned |
| 6. Admin addons and the catalog | Addons from a server folder, Admin › Addons to force them on or off, a catalog repo with checked hashes, updates | Server, every app | Planned |

Each phase also brings an example addon, such as
[the Solarized theme](design/addons/solarized), "Sort list", a word-count
badge or a webhook to ntfy.

Not planned for now: addon code running on the server, and CSS on Android,
which Flutter can't apply.
