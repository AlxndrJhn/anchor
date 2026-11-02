import { strToU8, zipSync } from "fflate";
import { afterEach, describe, expect, it, vi } from "vitest";
import { memoryStorage } from "@/lib/local-backend/db";
import { LocalServer } from "@/lib/local-backend/server";
import { addonsCss, addonsScript, addonThemeSelector } from "./apply";
import { checkAddon, cssProblems } from "./manifest";
import { fetchAddon, readAddon } from "./read";

const manifest = (overrides: Record<string, unknown> = {}) => ({
  id: "dev.example.solarized",
  name: "Solarized",
  version: "1.0.0",
  anchorApi: 1,
  contributes: { theme: { dark: { accent: "#B58900" } } },
  ...overrides,
});

const errorsOf = (m: unknown, files: unknown = {}) => {
  const check = checkAddon(m, files);
  return check.ok ? [] : check.errors;
};

// The server keeps the same rules: server/src/addons/addon-manifest.spec.ts.
describe("checkAddon", () => {
  it("keeps a theme, with its colours as custom themes have them", () => {
    const check = checkAddon(manifest(), {});
    expect(check.ok && check.addon.manifest.contributes).toEqual({
      theme: { dark: { accent: "#b58900" } },
    });
  });

  it("lists every problem", () => {
    expect(
      errorsOf({
        id: "Solarized",
        name: "",
        version: "one",
        anchorApi: 1,
        contributes: {},
        colour: "red",
      }),
    ).toEqual([
      "colour: unknown key",
      'id: use lower-case words with dots, like "dev.example.my-addon"',
      "name: must be text",
      'version: use a version like "1.0.0"',
    ]);
  });

  it("says what needs a newer Anchor+", () => {
    expect(
      errorsOf(
        manifest({
          anchorApi: 2,
          permissions: ["notes:read"],
          contributes: { commands: [] },
        }),
      ),
    ).toEqual([
      "permissions: needs a newer Anchor+",
      "anchorApi 2: needs a newer Anchor+",
      "contributes.commands: needs a newer Anchor+",
    ]);
  });

  it("refuses style files that are missing or reach outside the addon", () => {
    expect(
      errorsOf(manifest({ contributes: { styles: ["../x.css", "b.css"] } })),
    ).toEqual([
      'contributes.styles: "../x.css" must be a .css file in the addon',
      'contributes.styles: "b.css" is not in the addon',
    ]);
  });
});

describe("cssProblems", () => {
  it("lets data: URLs and plain CSS through", () => {
    expect(
      cssProblems(
        '/* see https://x.y */ .a{background:url("data:image/png;base64,AA");content:"\\201C"}',
      ),
    ).toEqual([]);
  });

  it.each([
    ['@import "x.css";', "@import is not allowed"],
    ["a{background:url(https://e.x/x)}", "url() may only hold a data: URL"],
    [
      "a{background:\\75rl(x)}",
      "escapes like \\75 are only allowed inside strings",
    ],
  ])("refuses %s", (css, problem) => {
    expect(cssProblems(css)).toContain(problem);
  });
});

describe("readAddon", () => {
  it("reads a .zip with the addon in a folder, keeping only what it uses", () => {
    const zip = zipSync({
      "solarized/addon.json": strToU8(
        JSON.stringify(manifest({ contributes: { styles: ["style.css"] } })),
      ),
      "solarized/style.css": strToU8(".card{border-radius:0}"),
      "solarized/README.md": strToU8("# Solarized"),
    });
    const check = readAddon("solarized.zip", zip);
    expect(check.ok && check.addon.files).toEqual({
      "style.css": ".card{border-radius:0}",
    });
  });

  it("reads an addon.json alone", () => {
    const check = readAddon("addon.json", strToU8(JSON.stringify(manifest())));
    expect(check.ok).toBe(true);
  });

  it("says when a .zip has no addon.json", () => {
    const zip = zipSync({ "style.css": strToU8("a{}") });
    expect(readAddon("x.zip", zip)).toEqual({
      ok: false,
      errors: ["The .zip has no addon.json"],
    });
  });
});

describe("fetchAddon", () => {
  afterEach(() => vi.unstubAllGlobals());

  it("downloads the style files an addon.json names from beside it", async () => {
    const fetch = vi.fn(async (url: string) =>
      url.endsWith("addon.json")
        ? new Response(
            JSON.stringify(
              manifest({ contributes: { styles: ["css/style.css"] } }),
            ),
          )
        : new Response(":root{--radius-card:4px}"),
    );
    vi.stubGlobal("fetch", fetch);
    const check = await fetchAddon("https://example.com/a/addon.json");
    expect(fetch).toHaveBeenLastCalledWith(
      "https://example.com/a/css/style.css",
      { credentials: "omit" },
    );
    expect(check.ok && check.addon.files).toEqual({
      "css/style.css": ":root{--radius-card:4px}",
    });
  });

  it("refuses addresses that aren't https", async () => {
    expect(await fetchAddon("http://example.com/addon.json")).toEqual({
      ok: false,
      errors: ["Use an https:// address"],
    });
  });
});

describe("addonsCss", () => {
  const addon = (id: string, enabled = true) => ({
    enabled,
    manifest: {
      ...manifest({ id }),
      contributes: {
        theme: { dark: { accent: "#b58900" } },
        styles: ["style.css"],
      },
    },
    files: { "style.css": `.${id.split(".").pop()}{}` },
  });

  it("puts each addon's colours, then its CSS, in the order installed", () => {
    expect(addonsCss([addon("dev.example.a"), addon("dev.example.b")])).toEqual(
      {
        css: [
          "/* dev.example.a */",
          `${addonThemeSelector("dark")}{--accent:#b58900;--inverse-link:#b58900;}`,
          ".a{}",
          "/* dev.example.b */",
          `${addonThemeSelector("dark")}{--accent:#b58900;--inverse-link:#b58900;}`,
          ".b{}",
        ].join("\n"),
        theme: true,
      },
    );
  });

  it("leaves out addons that are off", () => {
    expect(addonsCss([addon("dev.example.a", false)])).toEqual({
      css: "",
      theme: false,
    });
  });

  it("is put on the page before the first paint, except in safe mode", () => {
    const run = (search: string, safe: string | null) => {
      const appended: { id?: string; textContent?: string }[] = [];
      const html = { dataset: {} as Record<string, string> };
      const session = new Map<string, string>(
        safe ? [["addons-safe", safe]] : [],
      );
      new Function(
        "localStorage",
        "sessionStorage",
        "document",
        "location",
        addonsScript,
      )(
        {
          getItem: () => JSON.stringify({ css: ".a{}", theme: true }),
        },
        {
          getItem: (key: string) => session.get(key) ?? null,
          setItem: (key: string, value: string) => session.set(key, value),
        },
        {
          documentElement: html,
          head: { appendChild: (node: object) => appended.push(node) },
          createElement: () => ({}),
        },
        { search },
      );
      return { appended, dataset: html.dataset, session };
    };
    expect(run("", null)).toMatchObject({
      appended: [{ id: "addons", textContent: ".a{}" }],
      dataset: { addonTheme: "" },
    });
    expect(run("?safe", null)).toMatchObject({
      appended: [],
      session: new Map([["addons-safe", "1"]]),
    });
    expect(run("", "1").appended).toEqual([]);
  });
});

describe("LocalServer addons", () => {
  it("installs, updates, turns off and removes an addon", async () => {
    const server = new LocalServer(memoryStorage());
    const call = async (method: string, path: string, body?: unknown) => {
      const response = await server.handle(
        new Request(`http://localhost/api/${path}`, {
          method,
          headers: body ? { "Content-Type": "application/json" } : {},
          body: body ? JSON.stringify(body) : undefined,
        }),
      );
      const text = await response.text();
      return { status: response.status, body: text ? JSON.parse(text) : null };
    };

    const bad = await call("POST", "addons", {
      manifest: manifest({ version: "x" }),
      files: {},
    });
    expect(bad.status).toBe(400);
    expect(bad.body.errors).toEqual(['version: use a version like "1.0.0"']);

    const installed = await call("POST", "addons", {
      manifest: manifest(),
      files: {},
    });
    const updated = await call("POST", "addons", {
      manifest: manifest({ version: "1.1.0" }),
      files: {},
    });
    expect(updated.body).toMatchObject({
      id: installed.body.id,
      version: "1.1.0",
      enabled: true,
    });
    await call("PATCH", `addons/${installed.body.id}`, { enabled: false });
    expect((await call("GET", "addons")).body).toMatchObject([
      { enabled: false },
    ]);
    await call("DELETE", `addons/${installed.body.id}`);
    expect((await call("GET", "addons")).body).toEqual([]);
  });
});
