import { describe, expect, it } from "vitest";
import { licenseUrl, sourceCodeUrl } from "./source-code";

describe("sourceCodeUrl", () => {
  it("points a release at its tag", () => {
    expect(sourceCodeUrl("0.18.0.80")).toBe(
      "https://github.com/AlxndrJhn/anchor-plus/tree/fork-0.18.0.80",
    );
  });

  it("points any other build at main", () => {
    for (const version of ["0.18.0", "", undefined]) {
      expect(sourceCodeUrl(version)).toBe(
        "https://github.com/AlxndrJhn/anchor-plus/tree/main",
      );
    }
  });
});

describe("licenseUrl", () => {
  it("follows the same version", () => {
    expect(licenseUrl("0.18.0.80")).toBe(
      "https://github.com/AlxndrJhn/anchor-plus/blob/fork-0.18.0.80/LICENSE",
    );
  });
});
