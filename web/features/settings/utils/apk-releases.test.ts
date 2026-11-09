import { describe, expect, it } from "vitest";
import { pickApkReleases } from "./apk-releases";

const release = (
  tag: string,
  prerelease: boolean,
  hasApk = true,
  draft = false,
  name = `Anchor+ ${tag}`,
) => ({
  tag_name: tag,
  name,
  prerelease,
  draft,
  assets: hasApk
    ? [
        {
          name: tag.startsWith("fork-") ? "anchor-fork.apk" : "anchor-plus.apk",
          browser_download_url: `https://x/${tag}.apk`,
        },
      ]
    : [{ name: "anchor-desktop.exe", browser_download_url: "https://x/d" }],
});

describe("pickApkReleases", () => {
  it("takes the newest candidate and stable release that carry an APK", () => {
    expect(
      pickApkReleases([
        release("v0.18.0.75", true, true, true),
        release("v0.18.0.74", true, false),
        release("v0.18.0.73", true),
        release("v0.18.0.72", true),
        release("v0.18.0.70", false, false),
        release("v0.18.0.69", false),
        release("v0.18.0.60", false),
      ]),
    ).toEqual({
      candidate: { version: "0.18.0.73", url: "https://x/v0.18.0.73.apk" },
      stable: { version: "0.18.0.69", url: "https://x/v0.18.0.69.apk" },
    });
  });

  it("takes releases from before the rename, but not the bridge copies", () => {
    expect(
      pickApkReleases([
        release(
          "fork-0.18.0.82",
          false,
          true,
          false,
          "Anchor+ fork-0.18.0.82 (bridge)",
        ),
        release("v0.18.0.82", false, false),
        release("fork-0.18.0.80", false),
      ]),
    ).toEqual({
      candidate: null,
      stable: { version: "0.18.0.80", url: "https://x/fork-0.18.0.80.apk" },
    });
  });

  it("has no candidate when the stable release is the newest", () => {
    expect(
      pickApkReleases([
        release("v0.18.0.69", false),
        release("v0.18.0.68", true),
      ]).candidate,
    ).toBeNull();
  });
});
