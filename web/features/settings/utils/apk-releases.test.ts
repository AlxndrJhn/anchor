import { describe, expect, it } from "vitest";
import { pickApkReleases } from "./apk-releases";

const release = (
  tag: string,
  prerelease: boolean,
  hasApk = true,
  draft = false,
) => ({
  tag_name: tag,
  prerelease,
  draft,
  assets: hasApk
    ? [
        {
          name: "anchor-fork.apk",
          browser_download_url: `https://x/${tag}.apk`,
        },
      ]
    : [{ name: "anchor-desktop.exe", browser_download_url: "https://x/d" }],
});

describe("pickApkReleases", () => {
  it("takes the newest candidate and stable release that carry an APK", () => {
    expect(
      pickApkReleases([
        release("fork-0.18.0.75", true, true, true),
        release("fork-0.18.0.74", true, false),
        release("fork-0.18.0.73", true),
        release("fork-0.18.0.72", true),
        release("fork-0.18.0.70", false, false),
        release("fork-0.18.0.69", false),
        release("fork-0.18.0.60", false),
      ]),
    ).toEqual({
      candidate: { version: "0.18.0.73", url: "https://x/fork-0.18.0.73.apk" },
      stable: { version: "0.18.0.69", url: "https://x/fork-0.18.0.69.apk" },
    });
  });

  it("has no candidate when the stable release is the newest", () => {
    expect(
      pickApkReleases([
        release("fork-0.18.0.69", false),
        release("fork-0.18.0.68", true),
      ]).candidate,
    ).toBeNull();
  });
});
