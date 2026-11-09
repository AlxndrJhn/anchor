/** Where the Anchor+ Android app is released, with its APK for most phones. */
export const RELEASES_REPO = "AlxndrJhn/anchor-plus";
export const APK_ASSET = "anchor-plus.apk";
/** The same APK in releases from before they were renamed. */
const OLD_APK_ASSET = "anchor-fork.apk";

/** Works without asking GitHub: the newest stable release's APK. */
export const LATEST_APK_URL = `https://github.com/${RELEASES_REPO}/releases/latest/download/${APK_ASSET}`;

export interface ApkRelease {
  /** As "0.18.0.74". */
  version: string;
  url: string;
}

export interface ApkReleases {
  stable: ApkRelease | null;
  /** Only when newer than the stable one. */
  candidate: ApkRelease | null;
}

interface GithubRelease {
  tag_name: string;
  name?: string | null;
  draft: boolean;
  prerelease: boolean;
  assets: { name: string; browser_download_url: string }[];
}

/** v0.18.0.81 is 0.18.0.81, as was fork-0.18.0.80 before the rename. */
const versionOf = (tag: string) => tag.replace(/^(v|fork-)/, "");

/** A copy of a release under its old name, for apps from before the rename. */
const isBridge = (release: GithubRelease) =>
  release.name?.endsWith("(bridge)") ?? false;

/**
 * Not every release carries a new APK, so each channel takes the newest
 * release that does. GitHub lists releases newest first.
 */
export function pickApkReleases(releases: GithubRelease[]): ApkReleases {
  let stable: ApkRelease | null = null;
  let candidate: ApkRelease | null = null;
  for (const release of releases) {
    if (release.draft || isBridge(release)) continue;
    const apk =
      release.assets.find((asset) => asset.name === APK_ASSET) ??
      release.assets.find((asset) => asset.name === OLD_APK_ASSET);
    if (!apk) continue;
    const found = {
      version: versionOf(release.tag_name),
      url: apk.browser_download_url,
    };
    if (release.prerelease) {
      candidate ??= found;
    } else {
      stable = found;
      break;
    }
  }
  return { stable, candidate };
}

export async function fetchApkReleases(): Promise<ApkReleases> {
  const response = await fetch(
    `https://api.github.com/repos/${RELEASES_REPO}/releases?per_page=30`,
    { headers: { Accept: "application/vnd.github+json" } },
  );
  if (!response.ok) throw new Error(`GitHub answered ${response.status}`);
  return pickApkReleases(await response.json());
}
