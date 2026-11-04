/** Where the Anchor+ Android app is released, with its APK for most phones. */
export const RELEASES_REPO = "AlxndrJhn/anchor";
export const APK_ASSET = "anchor-fork.apk";

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
  draft: boolean;
  prerelease: boolean;
  assets: { name: string; browser_download_url: string }[];
}

const versionOf = (tag: string) => tag.replace(/^fork-/, "");

/**
 * Not every release carries a new APK, so each channel takes the newest
 * release that does. GitHub lists releases newest first.
 */
export function pickApkReleases(releases: GithubRelease[]): ApkReleases {
  let stable: ApkRelease | null = null;
  let candidate: ApkRelease | null = null;
  for (const release of releases) {
    if (release.draft) continue;
    const apk = release.assets.find((asset) => asset.name === APK_ASSET);
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
