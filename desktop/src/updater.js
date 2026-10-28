// Updates the desktop app from this fork's GitHub releases, as the Android
// app does: every release is tagged fork-<version>.<build>, and a build newer
// than this one is downloaded in the background. Once it is ready, onReady
// fires; install() quits, installs it and starts the new version.
//
// The release workflow writes the build number and repository into
// package.json (anchorBuild, anchorUpdateRepo); a build without them (local,
// unpackaged) never updates itself.

const { app, net } = require("electron");
const { spawn } = require("node:child_process");
const crypto = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");
const { Readable } = require("node:stream");
const { pipeline } = require("node:stream/promises");

const pkg = require("../package.json");

const FIRST_CHECK_MS = 15_000;
const CHECK_EVERY_MS = 4 * 60 * 60 * 1000;

const installedBuild = Number.parseInt(pkg.anchorBuild, 10) || 0;
const repository = typeof pkg.anchorUpdateRepo === "string" ? pkg.anchorUpdateRepo : "";

/** The build number in a release tag: `fork-0.17.2.22` is build 22. */
function buildOfTag(tag) {
  if (typeof tag !== "string" || !tag.startsWith("fork-")) return null;
  const build = Number.parseInt(tag.slice(tag.lastIndexOf(".") + 1), 10);
  return Number.isFinite(build) ? build : null;
}

/** This platform's installer among a release's assets. */
function installerAsset(assets) {
  const pattern = process.platform === "win32" ? /^Anchor-Setup-.*\.exe$/ : /^Anchor-.*\.dmg$/;
  return (assets ?? []).find((asset) => pattern.test(asset?.name ?? "")) ?? null;
}

/** The newest published release newer than this build that has an installer. */
function newestRelease(releases) {
  let best = null;
  for (const release of releases) {
    if (!release || release.draft || release.prerelease) continue;
    const build = buildOfTag(release.tag_name);
    if (build === null || build <= installedBuild || (best && build <= best.build)) continue;
    const asset = installerAsset(release.assets);
    if (asset) best = { build, tag: release.tag_name, pageUrl: release.html_url, asset };
  }
  return best;
}

// The .app bundle this runs from, if it can be replaced in place: not from
// the disk image, and not moved aside by Gatekeeper (App Translocation).
function replaceableBundle() {
  const bundle = path.resolve(app.getPath("exe"), "..", "..", "..");
  if (!bundle.endsWith(".app")) return null;
  if (bundle.startsWith("/Volumes/") || bundle.includes("/AppTranslocation/")) return null;
  try {
    fs.accessSync(path.dirname(bundle), fs.constants.W_OK);
    fs.accessSync(bundle, fs.constants.W_OK);
    return bundle;
  } catch {
    return null;
  }
}

const updatesDir = () => path.join(app.getPath("userData"), "updates");

async function download(asset, file) {
  // GitHub gives each asset's SHA-256; check it when it is there.
  const expected = /^sha256:([0-9a-f]{64})$/.exec(asset.digest ?? "")?.[1] ?? null;
  const res = await net.fetch(asset.browser_download_url, { cache: "no-store" });
  if (!res.ok || !res.body) throw new Error(`download answered ${res.status}`);
  const hash = crypto.createHash("sha256");
  const partial = `${file}.part`;
  const body = Readable.fromWeb(res.body);
  body.on("data", (chunk) => hash.update(chunk));
  await pipeline(body, fs.createWriteStream(partial));
  if (expected && hash.digest("hex") !== expected) {
    fs.rmSync(partial, { force: true });
    throw new Error("the download does not match its checksum");
  }
  fs.renameSync(partial, file);
}

/**
 * Starts checking for updates. onReady({ version }) fires when one can be
 * installed. Returns { current(), install() }, or null when this build does
 * not update itself.
 */
function startUpdater({ onReady, openExternal }) {
  const supported = process.platform === "win32" || process.platform === "darwin";
  if (!app.isPackaged || !supported || !installedBuild || !repository) return null;

  // { build, tag, pageUrl, file }: file is null when the update can only be
  // downloaded from its release page (the macOS app is not replaceable).
  let ready = null;
  let checking = false;

  async function check() {
    if (checking) return;
    checking = true;
    try {
      const res = await net.fetch(`https://api.github.com/repos/${repository}/releases?per_page=20`, {
        cache: "no-store",
        headers: { Accept: "application/vnd.github+json" },
      });
      if (!res.ok) throw new Error(`GitHub answered ${res.status}`);
      const release = newestRelease(await res.json());
      if (!release) {
        // Up to date: an installer left from the last update is not needed.
        fs.rmSync(updatesDir(), { recursive: true, force: true });
        return;
      }
      if (ready && ready.build >= release.build) return;

      let file = null;
      if (process.platform === "win32" || replaceableBundle()) {
        // One folder per release: an older download stays usable until the
        // newer one is complete, and a finished one is not fetched again.
        const dir = path.join(updatesDir(), release.tag);
        file = path.join(dir, release.asset.name);
        if (!fs.existsSync(file)) {
          fs.mkdirSync(dir, { recursive: true });
          await download(release.asset, file);
        }
        for (const name of fs.readdirSync(updatesDir())) {
          if (name !== release.tag) fs.rmSync(path.join(updatesDir(), name), { recursive: true, force: true });
        }
      }
      ready = { build: release.build, tag: release.tag, pageUrl: release.pageUrl, file };
      onReady(current());
    } catch (err) {
      console.error("Update check failed:", err);
    } finally {
      checking = false;
    }
  }

  function current() {
    return ready ? { version: ready.tag.replace(/^fork-/, "") } : null;
  }

  function install() {
    if (!ready) return false;
    if (!ready.file) {
      openExternal(ready.pageUrl);
      return true;
    }
    if (process.platform === "win32") {
      // The silent NSIS installer reuses the install folder, closes this app
      // if it is still running, and starts the new one when done.
      spawn(ready.file, ["/S", "--updated", "--force-run"], { detached: true, stdio: "ignore" }).unref();
    } else {
      const bundle = replaceableBundle();
      if (!bundle) {
        openExternal(ready.pageUrl);
        return true;
      }
      // Once this app has quit: copy the new app out of the disk image next
      // to the old one, swap them, and open it. If anything fails, the old
      // app stays and opens again.
      const script = `
        pid=$1 dmg=$2 app=$3
        while kill -0 "$pid" 2>/dev/null; do sleep 0.2; done
        mnt=$(mktemp -d)
        if hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$dmg"; then
          src=$(find "$mnt" -maxdepth 1 -name '*.app' | head -n 1)
          rm -rf "$app.new" "$app.old"
          if [ -n "$src" ] && ditto "$src" "$app.new"; then
            xattr -dr com.apple.quarantine "$app.new" 2>/dev/null
            if mv "$app" "$app.old"; then
              if mv "$app.new" "$app"; then rm -rf "$app.old"; else mv "$app.old" "$app"; fi
            fi
          fi
          rm -rf "$app.new"
          hdiutil detach "$mnt" -quiet || hdiutil detach "$mnt" -force -quiet
        fi
        rmdir "$mnt" 2>/dev/null
        open "$app"
      `;
      spawn("/bin/bash", ["-c", script, "anchor-update", String(process.pid), ready.file, bundle], {
        detached: true,
        stdio: "ignore",
      }).unref();
    }
    app.quit();
    return true;
  }

  setTimeout(check, FIRST_CHECK_MS);
  setInterval(check, CHECK_EVERY_MS);
  return { current, install };
}

module.exports = { startUpdater };
