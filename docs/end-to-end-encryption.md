# End-to-end encryption

Status: design, not built yet (2026-11-13)

Every account is encrypted end to end, always. Notes, tags, pictures and files are
encrypted on the device before they leave it, and the server only stores and passes on
ciphertext. Nobody who runs a server, hosted or self-hosted, can read what people write.

This document says what gets encrypted, how keys work, what each feature becomes, what
stays visible to the server, and the order to build it in.

## Goals and limits

**Goals**

- The server, its database, its backups and anyone who steals them see no note titles,
  text, checklists, tag names, pictures, files, file names, OCR text or picture-search
  data.
- Every way of signing in keeps working: password, OIDC, passkeys, sign-in codes from
  another device, two-step.
- Sharing with other people, share links, live editing, offline use, search, OCR and
  picture search keep working.
- Losing a password does not mean losing notes, as long as the person kept their
  recovery key or still has a signed-in device.

**What the server still sees** (metadata, needed to sync and share)

- Who has an account, when they sign in, from which IP.
- How many notes, tags and files someone has, their sizes and when each changed.
- Note colour, pinned, archived, trashed, order, lock kind, reminder times.
- Who shares which note with whom, and that a share link exists.

Encrypting more of this (colours, reminder times, the share graph) is possible later,
but each costs a server feature, so it is left out of the first version.

**What it does not protect against**

- A server operator who changes the **web app** code it serves can make it send keys
  away. The desktop and mobile apps don't load code from the server, so they are the
  safe choice; the web app is as trustworthy as the server that hosts it. Mitigations:
  published source, reproducible builds, and a notice in the web app that says so.
- A device that is itself compromised.
- Someone the note is shared with keeping a copy.

## Cryptography

One library on every platform, so all clients share one implementation of each
primitive and one set of test vectors:

- **libsodium**: `libsodium-wrappers-sumo` in web and desktop, `sodium_libs` in the
  Flutter app.
- **Symmetric**: XChaCha20-Poly1305 (`crypto_aead_xchacha20poly1305_ietf`), random
  24-byte nonces.
- **Files**: `crypto_secretstream_xchacha20poly1305` in 64 KiB chunks, so large files
  stream instead of loading whole into memory.
- **Password to key**: Argon2id (`crypto_pwhash`), 64 MiB memory, 3 passes. Parameters
  are stored with each wrapped key, so they can be raised later.
- **Key exchange for sharing**: X25519 sealed boxes (`crypto_box_seal`).
- **Keys**: 32 random bytes from `randombytes_buf`.

### Envelope

Every encrypted value is stored as one string:

```
enc:1:<base64url(nonce || ciphertext)>
```

The associated data binds a ciphertext to where it belongs (`note:<id>:body`,
`tag:<id>:name`, `attachment:<id>:meta`), so the server cannot swap one note's
ciphertext into another note or field without the client noticing.

## Keys

```
password ──Argon2id──► password key ──┐
recovery key (printed) ───────────────┤
passkey (WebAuthn PRF) ───────────────┼──► wraps ──► account key (random)
device key (secure storage) ──────────┘                   │
                                                          ├──► wraps ──► private key (X25519)
                                                          ├──► encrypts tag names, settings
                                                          └──► wraps ──► note keys (one per note)
                                                                              │
                                    sharee's public key ──► wraps ──► note key│
                                                                              ├──► note body
                                                                              ├──► revisions
                                                                              └──► file keys ──► files
```

- **Account key**: 32 random bytes, made on the device when the account is created. It
  never reaches the server unwrapped.
- **Wrapped copies** of the account key live on the server, one per way of unlocking:
  - **Password**: Argon2id of the password with a per-user salt. This is separate from
    the login check: the server keeps checking a bcrypt hash of a *different* value
    (derived from the same Argon2id output with a different context), so the login hash
    can't be used to unwrap anything.
  - **Recovery key**: 32 random bytes shown once as 24 words or a QR code at setup, and
    again on request in Settings. The account is not ready until the person confirms they
    saved it.
  - **Passkey**: the WebAuthn PRF extension gives a secret per passkey that wraps the
    account key. Supported in current Chrome, Safari and Android; where PRF is missing,
    a passkey only signs in and the device is unlocked another way.
  - **Device**: each signed-in device keeps a random device key in secure storage
    (Keychain/Keystore through `flutter_secure_storage`, Electron `safeStorage`, a
    non-extractable WebCrypto key in IndexedDB on the web) and a copy of the account key
    wrapped with it. Signing out deletes both.
- **Key pair**: an X25519 key pair per user. The public key is on the server; the
  private key is stored wrapped with the account key.
- **Note key**: 32 random bytes per note, wrapped with the account key for the owner and
  with the public key of each person the note is shared with.
- **File key**: per picture or file, wrapped with its note's key.

### Signing in on a new device

| Account | How the new device gets the account key |
|---|---|
| Password | Sign in, then the password unwraps it. |
| Passkey with PRF | The passkey sign-in unwraps it. |
| OIDC, or passkey without PRF | Scan a sign-in code from a device that is already signed in. The QR code carries the account key wrapped for a one-time key that never reaches the server. Without another device: the recovery key. |
| Any | The recovery key always works. |

The existing sign-in codes (`server/src/auth/magic-login.service.ts`) are extended for
this: the code in the QR stays the login, and a second secret in the URL fragment
carries the key.

### Changing and losing access

- **Changing the password** rewraps the account key. Nothing else is re-encrypted.
- **Forgotten password**: sign in another way (passkey, OIDC, another device) and set a
  new password, or use the recovery key.
- **Admin password reset** (`/api/admin/users/:id/reset-password` and
  `docker/reset-password`) resets the login only. The person then needs a device or
  their recovery key to read their notes. Both places say so before resetting.
- **Lost everything** (no password, device or recovery key): the notes cannot be
  recovered, by anyone. The account can be emptied and started over.

## What each part becomes

### Notes

Title, Quill content (text, checklists, formatting, inline picture references) are
encrypted together as the note's **body**. `Note.title` and `Note.content` are replaced
by `Note.body` (ciphertext) and `Note.keys` (the wrapped note keys). Colour, state,
version and timestamps stay as they are.

### Sync

The protocol in `server/src/sync` already treats a note as a whole row with
optimistic versions. It keeps doing that, with ciphertext in place of title and content:
a stale `baseVersion` still stores the rejected copy as a conflict revision and returns
the server copy, and the client merges. The web app moves from the `/api/notes` REST
calls to the same `/api/sync` protocol the mobile app uses, so there is one path for
encrypted data.

### Live editing

Today the server merges everyone's edits (`server/src/collab/collab-document.ts`). It
can no longer read them, so it becomes an ordering relay:

- A client sends an encrypted edit with the revision it is based on.
- If that is the latest revision, the server appends it to the note's log and forwards
  it to the others. If not, it refuses and sends the edits the client missed; the
  client rebases its edit on them (the same `quill-delta` transform the server uses
  today) and sends it again.
- Clients upload an encrypted full body every so often and when the last person leaves,
  so new joiners don't replay the whole log.

This keeps Quill's delta format and the existing editor code, instead of moving to a
CRDT such as Yjs.

### Search

Search moves to the device. The mobile app already searches its local database. The web
app decrypts notes into memory after unlocking and searches there
(`web/features/notes/search.ts` already does most of this). Notes and their search index
are kept encrypted in IndexedDB, never in plain text.

### OCR and picture search

Both run on the device, and their results are stored encrypted with the picture:

- **OCR**: tesseract.js on web and desktop (`web/lib/image-text.ts`), ML Kit on mobile
  (`mobile/lib/core/files/image_text_reader.dart`). Both exist already.
- **Picture search**: the SigLIP model through `onnxruntime-web` on web and desktop.
  On mobile, pictures added there get their vector the next time a web or desktop client
  of the same account is open; a mobile model comes later.
- The server's `picture-text.service.ts` and `picture-search/` are removed.

### Pictures and files

Encrypted with their file key before upload. File name, OCR text and the picture-search
vector go in an encrypted **meta** field next to it. MIME type and size stay plaintext
(the size is visible anyway).

### Tags

Tag names are encrypted with the account key. Colour and position stay plaintext.

### History

The server can't snapshot what it can't read, so revisions come from clients only (the
`recordClient` path that exists today), encrypted with the note key. Restoring a
revision happens on the device and syncs as a normal edit.

### Sharing with people

Sharing a note wraps its note key with the other person's public key. Removing someone
makes a new note key, re-encrypts the body and future revisions with it and wraps it for
the people who still have access. Their past copies can't be taken back.

A server could hand out a fake public key and read what is then shared. Against that,
each person's public key has a short fingerprint shown in the share dialog, which two
people can compare. Keys are trusted on first use and a changed key is flagged.

### Share links

The note key goes in the URL fragment (`/s/<token>#<key>`). Browsers don't send the
fragment to the server, and the share page is already a client-side page
(`web/app/s/[token]/shared-note-page.tsx`). Editing links join live editing with that
key. Revoking a link rotates the note key, as with people.

### Import, export and copy

- **Import**: Google Keep parsing already runs in the web app; it now encrypts before
  uploading. The server's import endpoint only stores rows.
- **Export**: built on the device (zip and Markdown), using the existing converters
  moved from `server/src/import-export` into shared code.
- **Copy**: the device decrypts, gives the copy a new note key and uploads.

### MCP and API tokens

The server can't read notes, so the hosted MCP endpoint (`server/src/mcp`) goes away.
Instead, a **local MCP bridge** runs on the person's computer: a small command (and an
option in the desktop app) that holds a device key, syncs, decrypts and serves the same
tools over stdio to Claude, ChatGPT and other assistants. The tool names stay the same.

### Reminders

Unchanged: reminders are scheduled on the device, which reads the title from its own
decrypted data. There is no server push to leak titles through.

### Self-hosting and the browser-only mode

Self-hosted servers run the same code, so they're encrypted end to end too. The
browser-only mode (`web/lib/local-backend`, `ANCHOR_MODE=local`) never sends anything
anywhere and stays as it is.

## Moving existing accounts

1. After the update, the next time someone opens a client they're asked to set up
   encryption: save the recovery key, and choose password, passkey or device unlock.
2. The client downloads every note, tag, revision and file, encrypts them and uploads
   the ciphertext, note by note, resuming if interrupted.
3. When the last item is done, the server deletes the plaintext columns, server-made
   revisions, OCR text and picture vectors for that account.
4. Backups made before that still contain plaintext. They age out under the normal
   retention, and the release notes say how long that is.

Notes shared between an encrypted and a not-yet-encrypted account are encrypted when
their owner moves. Until the owner has moved, the other person sees them as before.

The server refuses plaintext writes from an account once it has moved, and, after a
transition period announced in the release notes, from everyone.

## Build order

Each step is its own PR and leaves the app working.

1. **Encryption at rest on the server** (independent of the rest): encrypted volumes,
   object storage and backups. Not end to end, but it protects stolen disks and backups
   now.
2. **Move work to the clients, still in plaintext**: search, OCR, picture search,
   export, copy and history restore on the device; the web app switches to `/api/sync`.
   This removes the server's need to read notes before any encryption exists.
3. **Crypto core**: one TypeScript and one Dart module with the envelope format, key
   hierarchy and shared test vectors, plus account setup, unlocking, the recovery key
   and device linking through sign-in codes. Accounts get keys but nothing is encrypted
   yet.
4. **Encrypted notes, tags and files**: sync carries ciphertext; new notes are
   encrypted; existing accounts move as described above.
5. **Live editing as an ordering relay**.
6. **Sharing and share links** with wrapped note keys, fingerprints and key rotation.
7. **Local MCP bridge**, then removal of the server MCP endpoint.
8. **Clean-up**: drop the plaintext columns, server OCR, picture search and markdown
   code, and refuse plaintext writes.

## Open questions

- Argon2id parameters on older Android phones: measure, and fall back to lower memory
  with more passes if 64 MiB is too slow.
- Picture search on mobile: which model, or keep relying on a web or desktop client.
- Should colour, reminder times and the share graph be encrypted in a later version?
- How long the transition period for unmoved accounts on self-hosted servers should be.
- Whether to ship the local MCP bridge as part of the desktop app only, or also as a
  standalone `npx` command.
