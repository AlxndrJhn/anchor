#!/usr/bin/env bash
# Builds the fork's two F-Droid repositories from the APKs attached to its
# GitHub releases, into $1 (the Pages site):
#   fdroid/repo          releases
#   fdroid/preview/repo  releases and release candidates, whichever is newer
# Add one of them in F-Droid; switching is turning one off and the other on.
# Both are signed with the same key, and the APKs are the ones on GitHub, so
# either updates an Anchor+ installed from the other, or from GitHub.
#
# Needs: GH_TOKEN, GITHUB_REPOSITORY, SITE_URL (the Pages site's address),
# FDROID_KEYSTORE_BASE64 and FDROID_KEYSTORE_PASSWORD (a PKCS12 keystore with
# the key "fdroid"), ANDROID_HOME, and fdroidserver on the PATH.
set -euo pipefail

SITE=$(realpath "$1")
HERE=$(dirname "$(realpath "$0")")
WORK=$(mktemp -d)
# The newest releases each repository keeps. Each has three APKs of about
# 50 MB, and the Pages site may hold 1 GB.
KEEP=2

echo "$FDROID_KEYSTORE_BASE64" | base64 -d > "$WORK/keystore.p12"
RELEASES=$(gh api "repos/$GITHUB_REPOSITORY/releases?per_page=50" \
  --jq '[.[] | select((.draft | not) and any(.assets[]; .name == "anchor-fork.apk"))]')

# $1: the repository's directory under the site, $2: its name, $3: whether it
# has release candidates.
build() {
  local path=$1 name=$2 candidates=$3
  local dir="$WORK/$path"
  mkdir -p "$dir/repo/icons" "$dir/metadata"
  cp "$HERE"/metadata/*.yml "$dir/metadata/"
  cp "$HERE/../../web/public/web-app-manifest-512x512.png" "$dir/repo/icons/icon.png"
  cat > "$dir/config.yml" << EOF
repo_url: $SITE_URL/$path/repo
repo_name: $name
repo_description: >-
  Anchor+, a fork of the Anchor notes app, from
  https://github.com/$GITHUB_REPOSITORY. The APKs are the ones attached to its
  GitHub releases.
archive_older: 0
sdk_path: $ANDROID_HOME
repo_keyalias: fdroid
keystore: $WORK/keystore.p12
keystorepass: {env: FDROID_KEYSTORE_PASSWORD}
keypass: {env: FDROID_KEYSTORE_PASSWORD}
EOF
  chmod 0600 "$dir/config.yml"

  local filter='.[]'
  [ "$candidates" = true ] || filter='.[] | select(.prerelease | not)'
  local tag
  for tag in $(jq -r "[$filter][:$KEEP][].tag_name" <<< "$RELEASES"); do
    mkdir -p "$WORK/apks/$tag"
    # Releases are in both repositories: download each once.
    if [ -z "$(ls -A "$WORK/apks/$tag")" ]; then
      gh release download "$tag" --repo "$GITHUB_REPOSITORY" \
        --pattern 'anchor-fork*.apk' --dir "$WORK/apks/$tag"
    fi
    local apk
    for apk in "$WORK/apks/$tag"/*.apk; do
      # One name per file in the repository: anchor-fork-0.18.0.67-x86_64.apk
      local abi
      abi=$(basename "$apk" .apk)
      abi=${abi#anchor-fork}
      cp "$apk" "$dir/repo/anchor-$tag${abi:--arm64-v8a}.apk"
    done
  done

  (cd "$dir" && fdroid update --pretty)
  mkdir -p "$SITE/$path"
  cp -r "$dir/repo" "$SITE/$path/"
  echo "$name: $SITE_URL/$path/repo"
}

build fdroid "Anchor+" false
build fdroid/preview "Anchor+ preview" true

# The key's fingerprint, which a repository's address carries in F-Droid so
# that it trusts only this key.
FINGERPRINT=$(keytool -list -keystore "$WORK/keystore.p12" -storetype PKCS12 \
  -storepass "$FDROID_KEYSTORE_PASSWORD" -alias fdroid -v |
  sed -n 's/^\s*SHA256: //p' | tr -d ': ' | tr 'A-F' 'a-f')
echo "Fingerprint: $FINGERPRINT"
# A page to add them from: on a phone with F-Droid, the links open it.
STABLE="$SITE_URL/fdroid/repo?fingerprint=$FINGERPRINT"
PREVIEW="$SITE_URL/fdroid/preview/repo?fingerprint=$FINGERPRINT"
cat > "$SITE/fdroid/index.html" << EOF
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Anchor+ for F-Droid</title>
<style>
  body { font: 16px/1.5 system-ui, sans-serif; max-width: 40rem; margin: 2rem auto; padding: 0 1rem; }
  code { word-break: break-all; }
</style>
<h1>Anchor+ for F-Droid</h1>
<p>Add one of these repositories in F-Droid (Settings › Repositories › +),
or open its link on your phone. Then install Anchor+ from it; F-Droid keeps it
up to date.</p>
<h2>Releases</h2>
<p><a href="${STABLE/https:/fdroidrepos:}">Add “Anchor+”</a></p>
<p><code>$STABLE</code></p>
<h2>Preview</h2>
<p>Releases and release candidates, whichever is newer.</p>
<p><a href="${PREVIEW/https:/fdroidrepos:}">Add “Anchor+ preview”</a></p>
<p><code>$PREVIEW</code></p>
<h2>Switching</h2>
<p>Keep one of them on: turn the other off under Settings › Repositories.
Anchor+ updates from the one that is on; going back from preview to releases
waits for the next release, as F-Droid doesn’t install older versions.</p>
<p>Key fingerprint (SHA-256): <code>$FINGERPRINT</code></p>
</html>
EOF
rm -rf "$WORK"
