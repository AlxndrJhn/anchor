/**
 * An addon's addon.json, checked (design/addons.md). The server checks it
 * again in server/src/addons/addon-manifest.ts, which keeps the same rules;
 * change both together.
 *
 *   {
 *     "id": "dev.example.solarized", "name": "Solarized", "version": "1.0.0",
 *     "anchorApi": 1,
 *     "contributes": { "theme": { "dark": { … } }, "styles": ["style.css"] }
 *   }
 */
import { type CustomTheme, checkCustomTheme } from "@/lib/design/custom-theme";

/** The addon API this app speaks. */
export const ANCHOR_API = 1;
/** All of an addon's files together, in characters. */
export const MAX_ADDON_SIZE = 256 * 1024;

export interface AddonManifest {
  id: string;
  name: string;
  version: string;
  anchorApi: number;
  description?: string;
  author?: string;
  homepage?: string;
  contributes: {
    theme?: CustomTheme;
    styles?: string[];
  };
}

/** What an addon is installed from: its manifest and the files it uses. */
export interface AddonPackage {
  manifest: AddonManifest;
  files: Record<string, string>;
}

export type AddonCheck =
  | { ok: true; addon: AddonPackage }
  | { ok: false; errors: string[] };

const ID = /^[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+$/;
const VERSION = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;
/** A style file inside the addon: relative, never above it. */
export const STYLE_PATH = /^(?!\/)(?!.*\.\.)[\w./-]+\.css$/;

const TOP_LEVEL = [
  "id",
  "name",
  "version",
  "anchorApi",
  "description",
  "author",
  "homepage",
  "contributes",
];
const CONTRIBUTES = ["theme", "styles"];
/** Planned for later versions (design/addons.md), so named as such. */
const LATER = [
  "permissions",
  "platforms",
  "commands",
  "panels",
  "badges",
  "hooks",
];

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

const unknownKey = (path: string, key: string) =>
  LATER.includes(key)
    ? `${path}: needs a newer Anchor+`
    : `${path}: unknown key`;

/**
 * What in [css] could reach beyond the page: @import, and url() or
 * image-set() with anything but a data: URL. CSS escapes outside strings are
 * refused too, as they could spell either.
 */
export function cssProblems(css: string): string[] {
  const problems: string[] = [];
  const code = css.replace(/\/\*[\s\S]*?\*\//g, "");
  if (/@import/i.test(code)) problems.push("@import is not allowed");
  if (
    /url\(\s*(?!["']?\s*data:)/i.test(code) ||
    /image-set\(\s*["'](?!\s*data:)/i.test(code)
  )
    problems.push("url() may only hold a data: URL");
  const outsideStrings = code.replace(
    /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g,
    '""',
  );
  if (/\\[0-9a-f]/i.test(outsideStrings))
    problems.push("escapes like \\75 are only allowed inside strings");
  return problems;
}

/** Checks a manifest and its files, listing every problem it finds. */
export function checkAddon(manifest: unknown, files: unknown): AddonCheck {
  if (!isObject(manifest))
    return { ok: false, errors: ["addon.json must be a JSON object"] };
  const errors: string[] = [];
  for (const key of Object.keys(manifest))
    if (!TOP_LEVEL.includes(key)) errors.push(unknownKey(key, key));

  const string = (key: string, max: number, required: boolean) => {
    const value = manifest[key];
    if (value === undefined) {
      if (required) errors.push(`${key}: missing`);
      return undefined;
    }
    if (typeof value !== "string" || !value.trim()) {
      errors.push(`${key}: must be text`);
      return undefined;
    }
    if (value.length > max)
      errors.push(`${key}: longer than ${max} characters`);
    return value;
  };
  const id = string("id", 100, true);
  if (id && !ID.test(id))
    errors.push(
      'id: use lower-case words with dots, like "dev.example.my-addon"',
    );
  const name = string("name", 60, true);
  const version = string("version", 40, true);
  if (version && !VERSION.test(version))
    errors.push('version: use a version like "1.0.0"');
  const description = string("description", 300, false);
  const author = string("author", 100, false);
  const homepage = string("homepage", 300, false);
  if (homepage && !/^https:\/\/\S+$/.test(homepage))
    errors.push("homepage: must be an https:// address");

  const api = manifest.anchorApi;
  if (api === undefined) errors.push("anchorApi: missing; use 1");
  else if (typeof api !== "number" || !Number.isInteger(api) || api < 1)
    errors.push("anchorApi: must be a whole number, such as 1");
  else if (api > ANCHOR_API)
    errors.push(`anchorApi ${api}: needs a newer Anchor+`);

  const fileMap = isObject(files) ? files : {};
  if (!isObject(files)) errors.push("files: must be an object of file texts");
  const contributes: AddonManifest["contributes"] = {};
  const given = manifest.contributes;
  if (!isObject(given)) errors.push("contributes: missing");
  else {
    for (const key of Object.keys(given))
      if (!CONTRIBUTES.includes(key))
        errors.push(unknownKey(`contributes.${key}`, key));
    if (given.theme !== undefined) {
      const theme = checkCustomTheme(given.theme);
      if (theme.ok) contributes.theme = theme.theme;
      else
        errors.push(
          ...theme.errors.map((error) => `contributes.theme: ${error}`),
        );
    }
    if (given.styles !== undefined) {
      if (
        !Array.isArray(given.styles) ||
        !given.styles.every((path) => typeof path === "string")
      )
        errors.push(
          'contributes.styles: must be a list of files, like ["style.css"]',
        );
      else {
        for (const path of given.styles as string[]) {
          if (!STYLE_PATH.test(path))
            errors.push(
              `contributes.styles: "${path}" must be a .css file in the addon`,
            );
          else if (typeof fileMap[path] !== "string")
            errors.push(`contributes.styles: "${path}" is not in the addon`);
          else
            for (const problem of cssProblems(fileMap[path] as string))
              errors.push(`${path}: ${problem}`);
        }
        contributes.styles = given.styles as string[];
      }
    }
    if (!contributes.theme && !contributes.styles?.length && !errors.length)
      errors.push("contributes: give a theme or styles");
  }

  // Only the files the addon uses are kept.
  const used: Record<string, string> = {};
  for (const path of contributes.styles ?? [])
    if (typeof fileMap[path] === "string") used[path] = fileMap[path] as string;
  const size = Object.values(used).reduce((sum, text) => sum + text.length, 0);
  if (size > MAX_ADDON_SIZE)
    errors.push(
      `The addon's files are larger than ${MAX_ADDON_SIZE / 1024} KB`,
    );

  if (errors.length) return { ok: false, errors };
  return {
    ok: true,
    addon: {
      manifest: {
        id: id as string,
        name: name as string,
        version: version as string,
        anchorApi: api as number,
        ...(description && { description }),
        ...(author && { author }),
        ...(homepage && { homepage }),
        contributes,
      },
      files: used,
    },
  };
}
