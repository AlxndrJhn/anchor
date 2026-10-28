<div align="center">

<img src="https://raw.githubusercontent.com/AlxndrJhn/anchor/main/web/public/icons/anchor_icon.png" alt="Anchor" width="120" height="120">

# Anchor

**An offline first, self hostable note taking application**

[![Version](https://img.shields.io/github/v/release/AlxndrJhn/anchor?label=version&style=for-the-badge)](https://github.com/AlxndrJhn/anchor/releases)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg?style=for-the-badge)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg?style=for-the-badge&logo=docker)](https://github.com/AlxndrJhn/anchor/pkgs/container/anchor)
[![Discord](https://img.shields.io/discord/1487830114795257906?label=Discord&style=for-the-badge)](https://discord.gg/sAfqjy8EYK)

<a href="https://trendshift.io/repositories/18646" target="_blank"><img src="https://trendshift.io/api/badge/repositories/18646" alt="ZhFahim%2Fanchor | Trendshift" style="width: 250px; height: 55px;" width="250" height="55"/></a>

Anchor focuses on speed, privacy, simplicity, and reliability across mobile and web. Notes are stored locally, editable offline, and synced across devices when online.

</div>

## Try it in your browser

Each release also publishes the web app on GitHub Pages, without a server:

- **[alxndrjhn.github.io/anchor](https://alxndrjhn.github.io/anchor/)**: the
  app itself. Your notes, tags and pictures stay in this browser (IndexedDB)
  and never leave it; Settings › Import and export backs them up.
- **[alxndrjhn.github.io/anchor/demo](https://alxndrjhn.github.io/anchor/demo/)**:
  a playground with sample notes, kept in memory only: a reload starts it
  over. Settings › Feature demos plays a short demo of each feature, after
  which it's yours to try; each has its own address, such as
  [/demo/freeze](https://alxndrjhn.github.io/anchor/demo/freeze).

Without a server there is no syncing, sharing, sign-in, API token or picture
search. To publish your own copy, set Settings › Pages › Source to "GitHub
Actions"; the workflow is `.github/workflows/pages.yml`, and
`BASE_PATH=/anchor pnpm build:pages` (in `web/`) builds the same site into
`web/out`.

## Anchor vs this fork

This is a fork of [ZhFahim/anchor](https://github.com/ZhFahim/anchor), kept up
to date with it. Everything upstream does, this fork does too; these are the
differences. "Web" and "Android" say where each one is available.

| | Web | Android |
|---|:---:|:---:|
| **Notes and lists** | | |
| Drag notes to arrange them, as in Google Keep: the others make room as you drag, and a moved note stays put until it is edited again (Android: hold a card, then drag) | ✓ | ✓ |
| A Select button for choosing several notes; holding a card without moving still selects it | | ✓ |
| Make a copy of a note, with its pictures and attachments | ✓ | ✓ |
| Freeze a note: nobody can change, trash or delete it until its owner unfreezes it (freezing needs a connection) | ✓ | ✓ |
| Make a note invisible: it stays out of your lists and only a search finds it; filter by "Invisible" to list them | ✓ | ✓ |
| Send a note to other apps as text (checklists as ☐/☑) | ✓ | ✓ |
| Change the colour of many selected notes at once | ✓ | ✓ |
| Tick checklist items straight from the notes list ([#70](https://github.com/ZhFahim/anchor/issues/70)) | ✓ | ✓ |
| Show checkboxes / Hide checkboxes, Untick all, Delete ticked items | ✓ | ✓ |
| A new note opens with the cursor in its text | ✓ | ✓ |
| Delete without a confirmation, with Undo instead | (upstream) | ✓ |
| Archive a note without a confirmation: the archive button gets a dot, as the pin does, and archiving unpins | | ✓ |
| A new note can be pinned or archived before anything is written in it | | ✓ |
| Pinned and Others headings in the notes list | (upstream) | ✓ |
| Option to hide pictures on note cards ([#177](https://github.com/ZhFahim/anchor/issues/177)) | ✓ | ✓ |
| Empty the trash in one go | (upstream) | ✓ |
| Merge selected notes into the first one picked (Select notes › More), with Undo | | ✓ |
| Cards say Today and Yesterday, and add the year to dates from other years | | ✓ |
| Larger checkboxes on cards; ticking one no longer jolts the list | | ✓ |
| **Search** | | |
| Filters for colour, tag, pictures, checklists and reminders | ✓ | ✓ |
| Search with a regular expression, or matching case; a filter for notes that contain a secret (ids, keys and tokens, passwords) | | ✓ |
| Search finds the text in pictures (screenshots, receipts), read on the server | ✓ | ✓ |
| Opt-in: find notes by what their pictures show ("Katzen", "receipt"), in most languages, on your server | ✓ | ✓ |
| With that on, an opened picture can show what it depicts as tags (English or German); a tag searches for it | ✓ | ✓ |
| Search also finds archived notes; Archive and Trash can be searched ([#190](https://github.com/ZhFahim/anchor/issues/190)) | ✓ | ✓ |
| The searched words are marked in the note you open ([#134](https://github.com/ZhFahim/anchor/issues/134)) | ✓ | ✓ |
| The search is kept when you come back from a note ([#206](https://github.com/ZhFahim/anchor/issues/206)) | ✓ | ✓ |
| Tag counts include archived notes, and a tag lists them ([#114](https://github.com/ZhFahim/anchor/issues/114)) | ✓ | ✓ |
| Tags can be put in any order by dragging their handle; the order syncs | ✓ | ✓ |
| A tag's colour can be changed from its menu | ✓ | ✓ |
| Text colour, font (serif, monospace, Comic Sans, handwriting, typewriter, rounded, slab, marker) and highlights in any colour, picked or preset | ✓ | ✓ |
| A deleted note burns away like a destroyed card in Balatro, its last sparks fading out (off with reduced motion) | ✓ | ✓ |
| **Pictures, files and recordings** | | |
| Grab image text (OCR): marks the text on a picture to select (drag over words or draw a box), copy or insert in the note | ✓ | ✓ |
| Paste a picture to add it as an attachment | ✓ | ✓ |
| Click a card's picture to view it full size | ✓ | ✓ |
| Share a picture you're viewing, or copy it to the clipboard | | ✓ |
| Every picture is downloaded to the phone, so none waits for a connection | | ✓ |
| A picture pasted from the keyboard or with Paste picture goes into the text at the caret | | ✓ |
| Record audio straight into a note | ✓ | |
| Attach any kind of file; Android can also attach a whole folder, zipped | ✓ | ✓ |
| Add image, Take picture and Take several (one picture after another, without going back to the note) in an opened note's menu | | ✓ |
| Camera and pictures buttons left of the text styles put pictures in the text at the caret; drag a picture's corner to resize it, hold it to retake, crop, mirror, caption or delete it | (shows them) | ✓ |
| Download pictures and recordings ([#164](https://github.com/ZhFahim/anchor/issues/164)) | | ✓ |
| Share to Anchor from other apps: text, links, pictures, files ([#52](https://github.com/ZhFahim/anchor/issues/52)) | | ✓ |
| **History** | | |
| Each version shows its added (+) and removed (−) lines | ✓ | ✓ |
| **Offline** | | |
| Open, edit and create notes without a connection, even after a reload; changes sync when back online ([#202](https://github.com/ZhFahim/anchor/issues/202)) | ✓ | (upstream) |
| Back up every note, tag, picture and recording to a .zip file, and restore one: missing notes come back and sync up, notes already there are left alone (Settings › Backup) | | ✓ |
| **Reminders** | | |
| Done button on the reminder notification | | ✓ |
| **Appearance** | | |
| Colour schemes: Nord, Dracula, Solarized, Gruvbox, Catppuccin, Tokyo Night, One, Rosé Pine, Monokai, GitHub | ✓ | ✓ |
| OLED colour scheme: pure black in dark mode, near-black outlined cards, white text | ✓ | ✓ |
| Custom theme from JSON (Settings › Appearance), kept on the device; the same JSON works on both ([how](#custom-themes)) | ✓ | ✓ |
| Styles: Skeuomorphism, Neo-Brutalism and Lo-fi | ✓ | ✓ |
| A skeuomorphic app icon everywhere: Android (adaptive and themed), iOS, the splash screens, the in-app logo, the web app and its home-screen icons | ✓ | ✓ |
| **Getting around** | | |
| Google Keep keyboard shortcuts ([#201](https://github.com/ZhFahim/anchor/issues/201)) | ✓ | |
| Tab (web) or Next (Android) in the title goes to the note text | ✓ | ✓ |
| Insert today's date ("Oct 28th 2026"): type /date (then Enter on the web, a space or Enter on Android); on the web also Ctrl+; (or a shortcut of your own), Ctrl+Shift+; for the date and time, and a choice of "2026-10-28" instead (Settings › Editor) | ✓ | ✓ |
| Long-press the app icon: New note, New checklist | | ✓ |
| Hold the New Note button for New list | | ✓ |
| Double-tap the New Note button to paste the clipboard into a new note | | ✓ |
| Updates itself from this fork's GitHub releases (Settings › Updates) | | ✓ |
| A new note gets the tag the list is filtered by | | ✓ |
| Back no longer closes the app by accident ([#136](https://github.com/ZhFahim/anchor/issues/136)); with a tag or filter on, it first shows all notes again | | ✓ |
| A chevron back to the top, two screens down the notes list | | ✓ |
| Starts faster: settings are read in one go while the splash shows | | ✓ |
| Debug mode: hold two fingers still for 3 s to film the app and its state, mark problems on a timeline and file them as a GitHub issue (see [mobile/README.md](mobile/README.md#debug-reports)) | | ✓ |
| The server's version in Settings › About | ✓ | |
| **Fixes** | | |
| Copying and saving the logs on Android ([#187](https://github.com/ZhFahim/anchor/issues/187), [#188](https://github.com/ZhFahim/anchor/issues/188)) | | ✓ |
| The notes list can scroll to the end with pinned notes and pictures | | ✓ |
| Next.js upgraded to 16.4.3 for security fixes | ✓ | |
| **Releases** | | |
| Running the "Release (fork)" workflow on `main` makes a release with the APK and a multi-arch Docker image (see [This Fork's Image](#this-forks-image)); the APK installs as "Anchor (fork)" next to the official app | ✓ | ✓ |
| A desktop app for Windows and macOS: your server's web client in its own window, in every release, that updates itself (see [Desktop App](#desktop-app)) | ✓ | |

### Custom themes

Settings › Appearance › Custom theme takes a theme as JSON. Paste it and
press Apply; Reset removes it; "Copy current theme as JSON" puts the colours
you see now (scheme and custom theme together) in the box and on the
clipboard, to start from. The theme is kept on that device only, like the
other appearance settings, and the same JSON works on the web and on
Android.

A custom theme sits on top of the chosen colour scheme: any colour it leaves
out is the scheme's. Lo-fi keeps its own pencil greys, so a custom theme
waits until another style is picked.

```json
{
  "name": "Ink",
  "light": {
    "background": "#f4f1ea",
    "card": "#fffdf8",
    "sidebar": "#ebe6db",
    "muted": "#e6e0d3",
    "foreground": "#1f1d1a",
    "mutedForeground": "#5c574e",
    "accent": "#2f6fdd",
    "accentStrong": "#2459b8",
    "accentInk": "#1d4a99",
    "border": "#d6cfc1",
    "divider": "#e3ddd0",
    "input": "#8a8375",
    "destructive": "#b3261e"
  },
  "dark": {
    "background": "#000",
    "card": "#111111",
    "accent": "#7aa2f7",
    "border": "#ffffff26"
  }
}
```

| Key | Meaning |
|---|---|
| `name` | Optional. Shown in Settings and used by "Copy current theme as JSON" |
| `light`, `dark` | The colours for light and dark mode. At least one is needed; a mode left out is the scheme's own |
| `background` | The page behind everything |
| `card` | Note cards, menus, dialogs and settings cards; also a plain note's colour |
| `sidebar` | The sidebar on the web; the drawer on Android |
| `muted` | Quiet fills: inputs, chips, loading placeholders |
| `foreground` | Text and icons |
| `mutedForeground` | Secondary text: dates, hints, captions |
| `accent` | Highlights: the selection on the web, links on dark panels (toasts) |
| `accentStrong` | Focus rings, switches, the text cursor; the selection on Android |
| `accentInk` | Links and accent-coloured text, where it has to read as text |
| `border` | Card and control outlines |
| `divider` | Lines between rows |
| `input` | Text field outlines |
| `destructive` | Delete buttons and error messages |

Colours are `#rgb`, `#rrggbb` or `#rrggbbaa` (the last two hex digits are
opacity), in upper or lower case. Any other key, or anything else as a
colour, is refused with a message naming the key and what is wrong with it
(`dark.backgroud: unknown key (did you mean "background"?)`), and nothing
changes until the JSON is fixed. The keys are the fields of the built-in
schemes in `design/schemes/schemes.json`; the parsers are
`web/lib/design/custom-theme.ts` and `mobile/lib/core/theme/custom_theme.dart`.

## Features

- **Rich Text Editor** - Create and edit notes with powerful formatting (bold, italic, underline, headings, lists, checkboxes)
- **Offline First** - All edits work offline with local database
- **Note Sharing** - Share notes with other users (viewer or editor)
- **Note History** - Read earlier versions of a note and put one back
- **Tags System** - Organize notes with custom tags and colors
- **Attachments** - Attach images and audio to notes
- **Note Backgrounds** - Customize notes with solid colors and patterns
- **Pin Notes** - Pin important notes for quick access
- **Archive Notes** - Archive notes for later reference
- **Reminders** - Set a time on any note and get a notification on your phone, once or repeating
- **Search** - Search notes locally by title or content
- **Trash** - Soft delete notes with recovery period
- **Automatic Sync** - Sync changes across devices when online
- **Import & Export** - Back up your full library, or move notes in and out as plain Markdown
- **Home Screen Widget** - Quick access to your notes from the Android home screen
- **Admin Panel** - User management, registration control, and system statistics
- **OIDC Authentication** - Sign in with OpenID Connect providers (Pocket ID, Authelia, Keycloak, etc.)

## Screenshots

### Web App

<div align="center">
  <img src="https://raw.githubusercontent.com/zhfahim/anchor/main/.github/assets/screenshot-web-light.png" alt="Web Light Mode" width="45%">
  <img src="https://raw.githubusercontent.com/zhfahim/anchor/main/.github/assets/screenshot-web-dark.png" alt="Web Dark Mode" width="45%">
</div>

### Mobile App

<div align="center">
  <img src="https://raw.githubusercontent.com/zhfahim/anchor/main/.github/assets/screenshot-mobile-light.jpg" alt="Mobile Light Mode" width="20%">
  <img src="https://raw.githubusercontent.com/zhfahim/anchor/main/.github/assets/screenshot-mobile-dark.jpg" alt="Mobile Dark Mode" width="20%">
</div>

## Self Hosting With Docker

### Option 1: Using Pre-built Image (Recommended)

1. **Create a `docker-compose.yml` file:**

   ```yaml
   services:
     anchor:
       image: ghcr.io/alxndrjhn/anchor:fork-latest
       container_name: anchor
       restart: unless-stopped
       ports:
         - "3000:3000"
       volumes:
         - anchor_data:/data

   volumes:
     anchor_data:
   ```

2. **(Optional) Configure environment:**
   Add environment variables to the `environment` section. Most users can skip this step - defaults work out of the box.

   Available options:
   | Variable | Required | Default | Description |
   |----------|----------|---------|-------------|
   | `APP_URL` | No | `http://localhost:3000` | Base URL where Anchor is served |
   | `JWT_SECRET` | No | (auto-generated) | Auth token secret. Min 16 characters when set |
   | `DATA_DIR` | No | `/data` | Root directory for persisted uploads |
   | `PICTURE_TEXT` | No | `on` | `off` stops reading the text in pictures for search |
   | `PICTURE_SEARCH` | No | `on` | `off` stops offering search by what pictures show (Settings › Search) |
   | `PICTURE_SEARCH_MODEL_URL` | No | (Hugging Face) | Where to download its model (~380 MB) from, e.g. a mirror |
   | `CORS_ORIGINS` | No | (allow all) | Comma-separated allowlist of CORS origins |
   | `PG_HOST` | No | (empty) | External Postgres host (leave empty for embedded) |
   | `PG_PORT` | No | `5432` | Postgres port |
   | `PG_USER` | No | `anchor` | Postgres username |
   | `PG_PASSWORD` | No | `password` | Postgres password |
   | `PG_DATABASE` | No | `anchor` | Database name |
   | `USER_SIGNUP` | No | (not set) | Sign up mode: `disabled`, `enabled`, or `review`. If not set, admins can control it via the admin panel |
   | `OIDC_ENABLED` | No | — | Enable OIDC authentication |
   | `OIDC_PROVIDER_NAME` | No | `"OIDC Provider"` | Display name for the login button |
   | `OIDC_ISSUER_URL` | When OIDC enabled | — | Base URL of your OIDC provider |
   | `OIDC_CLIENT_ID` | When OIDC enabled | — | OIDC client ID |
   | `OIDC_CLIENT_SECRET` | No | — | OIDC client secret. Omit for public client (PKCE) |
   | `DISABLE_INTERNAL_AUTH` | No | `false` | Hide local login form when OIDC is enabled (OIDC-only mode) |

3. **Start the container:**

   ```bash
   docker compose up -d
   ```

4. **Access the app:**
   Open http://localhost:3000

5. **Update later:**

   ```bash
   docker compose pull && docker compose up -d
   ```

### Image Tags

Every release of this fork is named `fork-<version>.<build>` and publishes a
multi-arch image (amd64 and arm64, so it runs on a Raspberry Pi 5):

| Tag | What it is |
|-----|------------|
| `ghcr.io/alxndrjhn/anchor:fork-latest` | The newest release |
| `ghcr.io/alxndrjhn/anchor:fork-<version>.<build>` | One release, e.g. `fork-0.17.2.36`, to stay on it |
| `ghcr.io/alxndrjhn/anchor:fork-<commit>` | The build of one commit |

The original project's image is `ghcr.io/zhfahim/anchor:latest`; it has none
of this fork's changes. Switching between them keeps your data, but back it
up first: this fork adds database columns the original doesn't know.

### Option 2: Building from Source

If you want to build from source or customize the image:

1. **Clone the project:**

   ```bash
   git clone https://github.com/AlxndrJhn/anchor.git
   cd anchor
   ```

2. **Build and start the container:**

   ```bash
   docker compose up -d --build
   ```

   `--build` builds the image from your checkout; without it, the
   `docker-compose.yml` file pulls this fork's released image.

## Mobile App

Download the Android mobile app.

1. **Visit the releases page:**
   Go to [GitHub Releases](https://github.com/AlxndrJhn/anchor/releases), or
   download the [latest APK](https://github.com/AlxndrJhn/anchor/releases/latest/download/anchor-fork.apk)
   directly.

2. **Download the latest release:**
   Each release has one APK per kind of phone:
   - **`anchor-fork.apk`** - 64-bit ARM, for nearly every phone
   - **`anchor-fork-armeabi-v7a.apk`** - older 32-bit ARM phones
   - **`anchor-fork-x86_64.apk`** - emulators and x86 devices

   Once installed, the app finds and installs new releases itself
   (Settings › Updates).

## Desktop App

A Windows and macOS app that opens the web client of your own Anchor server in
its own window, with everything the web app has (offline use, keyboard
shortcuts). It does not store notes itself; it connects to your server.

1. **Download it** from this fork's
   [releases page](https://github.com/AlxndrJhn/anchor/releases):
   - **Windows:** `Anchor-Setup-<version>.exe` (64-bit)
   - **macOS:** `Anchor-<version>-universal.dmg` (Apple silicon and Intel);
     open it and drag Anchor to Applications

2. **Connect:** on first launch, enter the address you open Anchor at in your
   browser, such as `https://notes.example.com`. The app checks that the server
   answers, then remembers it. **Change server…** (File menu on Windows, the
   Anchor menu on macOS) switches to another one.

The builds are not signed, so the system warns the first time:

- **macOS:** right-click Anchor in Applications and choose **Open**, then
  **Open** again; or try to open it once, then allow it under **System
  Settings › Privacy & Security** (**Open Anyway**).
- **Windows:** if SmartScreen says it protected your PC, choose
  **More info › Run anyway**.

The app keeps itself up to date: it looks for a newer release now and then,
downloads it in the background, and then shows a small **Update** button in
the top right (also **Restart to Update** in the File menu, or the Anchor menu
on macOS). Clicking it restarts Anchor on the new version. On macOS this needs
Anchor in a folder you can write to, such as Applications; run from the disk
image, the button opens the release page instead.

Links to other websites open in your browser. To build it yourself:
`cd desktop && pnpm install && pnpm run dist:win` (or `dist:mac`).

## OIDC Authentication

Anchor supports OpenID Connect (OIDC) authentication for simplified credential management and streamlined multi-user deployments.

### Features

- Support for standard OIDC providers (Pocket ID, Authelia, Authentik, Keycloak, etc.)
- Configuration via environment variables or admin settings UI
- OIDC only mode: disable local username/password login
- Support for public OIDC clients (PKCE, no client secret required)
- Auto create users on first login (if user signup is not disabled)
- Auto link existing users by email

### Configuration

#### Mobile app and Public client

If you want to use OIDC in the mobile app, configure Anchor as a **Public client** (PKCE, no client secret) in your OIDC provider. Add this redirect URI in your OIDC provider:

```
anchor://oidc/callback
```

#### Required Callback URL (Web)

When configuring your OIDC provider for web login, add this callback/redirect URL:

```
{APP_URL}/api/auth/oidc/callback
```

For example, if your Anchor instance is at `https://notes.example.com`, the callback URL would be:

```
https://notes.example.com/api/auth/oidc/callback
```

#### Environment Variables

Configure OIDC via environment variables in your `docker-compose.yml`. Pocket ID example:

```yaml
services:
  anchor:
    image: ghcr.io/alxndrjhn/anchor:fork-latest
    environment:
      - OIDC_ENABLED=true
      - OIDC_PROVIDER_NAME=Pocket ID
      - OIDC_ISSUER_URL=https://pocketid.example.com
      - OIDC_CLIENT_ID=your-client-id
      - OIDC_CLIENT_SECRET=your-client-secret # Optional for public clients
      - DISABLE_INTERNAL_AUTH=false
      - APP_URL=https://notes.example.com
```

#### Admin UI Configuration

Alternatively, configure OIDC via the admin panel (Settings → OIDC Authentication) when the three env vars are not all set.

## Keyboard Shortcuts (Web)

Modelled on Google Keep. Single keys work when no text field has focus.

| Where | Key | Action |
|---|---|---|
| Note lists | `C` | New note |
| | `L` | New checklist |
| | `/` or `Ctrl/⌘ K` | Search |
| | `Ctrl/⌘ A` | Select all notes |
| Open note | `E` | Archive / unarchive |
| | `#` | Move to trash |
| | `F` | Pin / unpin |
| | `Esc` | Close the note (in a text field, the first `Esc` leaves the field) |
| | `Ctrl/⌘ Enter` | Close the note, from anywhere |
| In the text | `Ctrl/⌘ Shift 8` | Checklist on / off |
| | `Ctrl/⌘ ]` / `Ctrl/⌘ [` | Indent / outdent list item |
| | `Tab` in the title | Jump to the note text |

## Backup and Restore

Log into your Anchor deployment, go to **Settings**, scroll to **Export & Import** and export **Anchor backup (.zip)**.

The resulting `anchor-export-YYYY-MM-DD.zip` contains:

- `manifest.json` which includes the backup metadata, tags, notes, and attachment references in plain text
- the referenced attachments, stored within the `attachments` folder structure

Restore the notes by uploading that file through the web UI. Go to **Settings**, then scroll down to the **Export & Import** section.

## Troubleshooting & Collecting Logs

Anchor never collects any data. When you need to report a bug, you can collect logs yourself and share them with the maintainer.

**Mobile app**

1. Reproduce the issue.
2. Open Settings → View Logs.
3. Tap the **Export** button at the bottom, then share the saved `.log` file in your bug report.

> Sensitive values are stripped before anything is written to the log file. This includes authorization headers, passwords, tokens, refresh tokens, secrets, and email addresses, which are always replaced with `***`.

Logs are stored locally on the device only (rolling, ~2 MB max).

## Roadmap

Future planned features:

- Real-time collaboration

## Tech Stack

- **Backend**: Nest.js, PostgreSQL, Prisma
- **Mobile**: Flutter
- **Web**: Next.js, TypeScript

## Contributing

1. Fork the repository
2. Create a feature branch:
   ```bash
   git checkout -b feature/your-feature
   ```
3. Make your changes
4. Ensure builds pass and code is linted:
   - Web: `cd web && pnpm build && pnpm check`
   - Server: `cd server && pnpm build && pnpm check`
5. Commit changes:
   ```bash
   git commit -m "Describe your change"
   ```
6. Push and create a Pull Request

### Code style

Linting and formatting are enforced in CI and by a pre-commit hook
(`.githooks/pre-commit`) that checks staged files.
Running `pnpm install` in either `web` or `server`
enables the hook automatically (via the `prepare` script). To enable it manually:

```bash
git config core.hooksPath .githooks
```

Before committing, fix issues with `pnpm check:fix` in the relevant project.

### Design tokens

The web app's colors, text sizes, spacing, corners, shadows and motion live in
`design/tokens/` (W3C Design Tokens format). `web/app/styles/tokens.css`,
`web/app/styles/notes.css` and `web/lib/design/tokens.ts` are built from them,
so change the tokens rather than those files. After changing a token, run this
from the repository root (it reads icons from `web/node_modules`, so run
`pnpm install` in `web` first):

```bash
node design/build/build.mjs
```

CI runs it with `--check` and fails if the built files are out of date.

## Support

If you find Anchor useful, consider supporting its development:

[<img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy me a coffee" height="60">](https://www.buymeacoffee.com/zahid)

## License

This project is licensed under the GNU Affero General Public License v3.0 (AGPL v3) - see the [LICENSE](LICENSE) file for details.
