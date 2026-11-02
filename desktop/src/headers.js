// Extra headers sent with every request to one server, for a proxy in front
// of it (Cloudflare Access, an API gateway). Typed as on Android: one
// `Name: value` per line, the way a proxy's setup page shows them. Blank
// lines and lines starting with # are skipped.

/** Characters a header name may have (RFC 9110 tokens). */
const HEADER_NAME = /^[!#$%&'*+\-.^_`|~0-9A-Za-z]+$/;

/** Characters a header value may have on the wire. */
const HEADER_VALUE = /^[\t\x20-\x7E\x80-\xFF]+$/;

/** Headers the app or the browser sets itself: one typed here would replace it. */
const RESERVED_NAMES = new Set([
  "accept",
  "authorization",
  "connection",
  "content-length",
  "content-type",
  "cookie",
  "host",
  "origin",
  "transfer-encoding",
  "user-agent",
  "x-anchor-protocol",
]);

// The Android app's messages (serverHeaderNotNameValue…).
const PROBLEMS = {
  notNameValue: (line) => `Line ${line} needs a name and a value, as Name: value.`,
  badName: (line) => `Line ${line}: the name can have only letters, digits and - _ .`,
  badValue: (line) => `Line ${line}: the value has characters a header can’t carry.`,
  reservedName: (line) => `Line ${line}: Anchor sets this header itself.`,
  repeatedName: (line) => `Line ${line} repeats a name from above.`,
};

/** The well-formed headers in text, and the lines that aren't (counting from 1). */
function parseServerHeaders(text) {
  const headers = {};
  const seen = new Set();
  const errors = [];
  const lines = String(text ?? "").split(/\r\n|\r|\n/);
  lines.forEach((raw, i) => {
    const line = raw.trim();
    if (!line || line.startsWith("#")) return;
    const colon = line.indexOf(":");
    const name = colon < 0 ? "" : line.slice(0, colon).trim();
    const value = colon < 0 ? "" : line.slice(colon + 1).trim();
    const lowered = name.toLowerCase();
    const problem =
      colon <= 0 || !value
        ? "notNameValue"
        : !HEADER_NAME.test(name)
          ? "badName"
          : !HEADER_VALUE.test(value)
            ? "badValue"
            : RESERVED_NAMES.has(lowered)
              ? "reservedName"
              : seen.has(lowered)
                ? "repeatedName"
                : null;
    if (!problem) seen.add(lowered);
    if (problem) errors.push({ line: i + 1, problem });
    else headers[name] = value;
  });
  return { headers, errors };
}

/** What to show for the first line that is wrong, or null. */
function headersError(text) {
  const [first] = parseServerHeaders(text).errors;
  return first ? PROBLEMS[first.problem](first.line) : null;
}

/** The saved headers for serverUrl, none when they were saved for another server. */
function headersFor(saved, serverUrl) {
  if (!saved || !serverUrl || saved.server !== serverUrl) return {};
  return parseServerHeaders(saved.text).headers;
}

/** Whether a request to url goes to the server at serverUrl (http or ws). */
function isToServer(url, serverUrl) {
  if (!serverUrl) return false;
  const asHttp = String(url).replace(/^ws(s?):/i, "http$1:");
  return asHttp === serverUrl || asHttp.startsWith(`${serverUrl}/`);
}

module.exports = { parseServerHeaders, headersError, headersFor, isToServer };
