// node --test: the Help menu's links go to the version that is running.
const assert = require("node:assert/strict");
const { test } = require("node:test");
const { sourceCodeUrl, licenseUrl } = require("../src/legal");

test("a release points at its tag", () => {
  assert.equal(
    sourceCodeUrl("0.18.0", 80),
    "https://github.com/AlxndrJhn/anchor-plus/tree/v0.18.0.80",
  );
  assert.equal(
    licenseUrl("0.18.0", 80),
    "https://github.com/AlxndrJhn/anchor-plus/blob/v0.18.0.80/LICENSE",
  );
});

test("a build without a number points at main", () => {
  assert.equal(
    sourceCodeUrl("0.18.0", undefined),
    "https://github.com/AlxndrJhn/anchor-plus/tree/main",
  );
});
