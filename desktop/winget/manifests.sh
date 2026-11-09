#!/usr/bin/env bash
# Writes the winget manifests for a release's Windows installer, for
# `winget install AlxndrJhn.AnchorPlus`. The release workflow sends them to
# microsoft/winget-pkgs (wingetcreate submit); `winget validate` checks them.
#
#   desktop/winget/manifests.sh <version> <tag> <repository> <installer> <out dir>
#   desktop/winget/manifests.sh 0.18.0.71 fork-0.18.0.71 AlxndrJhn/anchor-plus \
#     Anchor-Setup-0.18.0.exe manifests
#
# <version> is the build's: the installer names it in Apps & features
# (build/installer.nsh), so winget sees which build is installed.
set -euo pipefail

if [ $# -ne 5 ]; then
  sed -n '2,8p' "$0" >&2
  exit 2
fi
VERSION=$1 TAG=$2 REPOSITORY=$3 INSTALLER=$4 OUT=$5

ID=AlxndrJhn.AnchorPlus
MANIFEST_VERSION=1.10.0
# The installer's key under ...\CurrentVersion\Uninstall: electron-builder
# derives it from the appId in electron-builder.yml.
PRODUCT_CODE=ef93823b-951e-5176-869c-26d36074c417
URL="https://github.com/$REPOSITORY/releases/download/$TAG/$(basename "$INSTALLER")"
SHA256=$(sha256sum "$INSTALLER" | cut -d' ' -f1)
SHA256=${SHA256^^}
SCHEMA=https://aka.ms/winget-manifest

mkdir -p "$OUT"

cat > "$OUT/$ID.yaml" <<EOF
# yaml-language-server: \$schema=$SCHEMA.version.$MANIFEST_VERSION.schema.json
PackageIdentifier: $ID
PackageVersion: $VERSION
DefaultLocale: en-US
ManifestType: version
ManifestVersion: $MANIFEST_VERSION
EOF

# One installer for both scopes: per user unless asked for all users.
cat > "$OUT/$ID.installer.yaml" <<EOF
# yaml-language-server: \$schema=$SCHEMA.installer.$MANIFEST_VERSION.schema.json
PackageIdentifier: $ID
PackageVersion: $VERSION
InstallerType: nullsoft
InstallModes:
  - interactive
  - silent
  - silentWithProgress
UpgradeBehavior: install
ProductCode: $PRODUCT_CODE
ReleaseDate: $(date -u +%Y-%m-%d)
AppsAndFeaturesEntries:
  - DisplayName: Anchor+
    Publisher: Anchor+
    DisplayVersion: $VERSION
    ProductCode: $PRODUCT_CODE
Installers:
  - Architecture: x64
    Scope: user
    InstallerUrl: $URL
    InstallerSha256: $SHA256
    InstallerSwitches:
      Custom: /currentuser
  - Architecture: x64
    Scope: machine
    InstallerUrl: $URL
    InstallerSha256: $SHA256
    InstallerSwitches:
      Custom: /allusers
ManifestType: installer
ManifestVersion: $MANIFEST_VERSION
EOF

cat > "$OUT/$ID.locale.en-US.yaml" <<EOF
# yaml-language-server: \$schema=$SCHEMA.defaultLocale.$MANIFEST_VERSION.schema.json
PackageIdentifier: $ID
PackageVersion: $VERSION
PackageLocale: en-US
Publisher: Anchor+
PublisherUrl: https://github.com/${REPOSITORY%%/*}
PublisherSupportUrl: https://github.com/$REPOSITORY/issues
PackageName: Anchor+
PackageUrl: https://github.com/$REPOSITORY
License: AGPL-3.0
LicenseUrl: https://github.com/$REPOSITORY/blob/main/LICENSE
ShortDescription: Notes from your own Anchor server, in a window of their own.
Description: |-
  Anchor+ opens the web client of your own Anchor server in its own window,
  with everything the web app has: offline use, keyboard shortcuts, reminders.
  It does not store notes itself; on first launch it asks for your server's
  address. It keeps itself up to date.
Moniker: anchorplus
Tags:
  - notes
  - note-taking
  - self-hosted
  - markdown
ReleaseNotesUrl: https://github.com/$REPOSITORY/releases/tag/$TAG
ManifestType: defaultLocale
ManifestVersion: $MANIFEST_VERSION
EOF

echo "Wrote the $ID $VERSION manifests to $OUT"
