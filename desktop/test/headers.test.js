// node --test: the extra headers read as the Android app reads them.
const assert = require("node:assert/strict");
const { test } = require("node:test");
const { parseServerHeaders, headersError, headersFor, isToServer } = require("../src/headers");

test("reads one Name: value per line, as a proxy shows them", () => {
  const { headers, errors } = parseServerHeaders(
    "CF-Access-Client-Id: abc.access\nCF-Access-Client-Secret:  s3cr3t:with:colons  \n",
  );
  assert.deepEqual(errors, []);
  assert.deepEqual(headers, {
    "CF-Access-Client-Id": "abc.access",
    "CF-Access-Client-Secret": "s3cr3t:with:colons",
  });
});

test("skips blank lines and # notes, and takes Windows line ends", () => {
  const { headers, errors } = parseServerHeaders("# from the tunnel page\r\n\r\nX-Token: 1\r\n   \r\n");
  assert.deepEqual(errors, []);
  assert.deepEqual(headers, { "X-Token": "1" });
});

test("names each line that is wrong, counting from 1", () => {
  const { headers, errors } = parseServerHeaders(
    [
      "X-Good: yes",
      "no colon here",
      ": no name",
      "X-Empty:",
      "Bad Name: 1",
      "X-Emoji: ⚓",
      "Authorization: Bearer x",
      "x-anchor-protocol: 9",
      "x-good: again",
    ].join("\n"),
  );
  assert.deepEqual(headers, { "X-Good": "yes" });
  assert.deepEqual(errors, [
    { line: 2, problem: "notNameValue" },
    { line: 3, problem: "notNameValue" },
    { line: 4, problem: "notNameValue" },
    { line: 5, problem: "badName" },
    { line: 6, problem: "badValue" },
    { line: 7, problem: "reservedName" },
    { line: 8, problem: "reservedName" },
    { line: 9, problem: "repeatedName" },
  ]);
});

test("the first wrong line is what the page shows", () => {
  assert.equal(headersError("X-Token: 1\nAuthorization: Bearer x"), "Line 2: Anchor sets this header itself.");
  assert.equal(headersError(""), null);
});

test("they go only to the server they were saved for", () => {
  const saved = { server: "https://notes.example.com", text: "X-Token: 1" };
  assert.deepEqual(headersFor(saved, "https://notes.example.com"), { "X-Token": "1" });
  assert.deepEqual(headersFor(saved, "https://other.example.com"), {});
  assert.deepEqual(headersFor(saved, "http://notes.example.com"), {});
  assert.deepEqual(headersFor(null, "https://notes.example.com"), {});
});

test("a request is to the server under its address, websockets too", () => {
  const server = "https://notes.example.com";
  assert.ok(isToServer("https://notes.example.com/api/notes", server));
  assert.ok(isToServer("wss://notes.example.com/socket", server));
  assert.ok(!isToServer("https://notes.example.com.evil.test/", server));
  assert.ok(!isToServer("https://login.example.com/authorize", server));
  assert.ok(!isToServer("https://notes.example.com/", undefined));
});
