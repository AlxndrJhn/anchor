/**
 * An addon's addon.json, checked before it is kept (design/addons.md). The
 * web app checks it first, in web/lib/addons/manifest.ts, which keeps the same
 * rules; change both together.
 */

/** The addon API this server keeps addons for. */
export const ANCHOR_API = 1;
/** All of an addon's files together, in characters. */
export const MAX_ADDON_SIZE = 256 * 1024;

/** A colour scheme's fields, as in design/schemes/schemes.json. */
export const PALETTE_FIELDS = [
  'background',
  'card',
  'sidebar',
  'muted',
  'foreground',
  'mutedForeground',
  'accent',
  'accentStrong',
  'accentInk',
  'border',
  'divider',
  'input',
  'destructive',
] as const;

type Palette = Partial<Record<(typeof PALETTE_FIELDS)[number], string>>;

export interface AddonManifest {
  id: string;
  name: string;
  version: string;
  anchorApi: number;
  description?: string;
  author?: string;
  homepage?: string;
  contributes: {
    theme?: { name?: string; light?: Palette; dark?: Palette };
    styles?: string[];
  };
}

export interface AddonPackage {
  manifest: AddonManifest;
  files: Record<string, string>;
}

export type AddonCheck =
  { ok: true; addon: AddonPackage } | { ok: false; errors: string[] };

const ID = /^[a-z0-9][a-z0-9-]*(?:\.[a-z0-9][a-z0-9-]*)+$/;
const VERSION = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;
const STYLE_PATH = /^(?!\/)(?!.*\.\.)[\w./-]+\.css$/;
const COLOR = /^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i;

const TOP_LEVEL = [
  'id',
  'name',
  'version',
  'anchorApi',
  'description',
  'author',
  'homepage',
  'contributes',
];
const CONTRIBUTES = ['theme', 'styles'];
const LATER = [
  'permissions',
  'platforms',
  'commands',
  'panels',
  'badges',
  'hooks',
];

const isObject = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const unknownKey = (path: string, key: string) =>
  LATER.includes(key)
    ? `${path}: needs a newer Anchor+`
    : `${path}: unknown key`;

/** As the web app's normalizeColor: lower-case #rrggbb or #rrggbbaa. */
function normalizeColor(value: string): string | null {
  if (!COLOR.test(value)) return null;
  const hex = value.slice(1).toLowerCase();
  if (hex.length === 3)
    return `#${[...hex].map((digit) => digit + digit).join('')}`;
  if (hex.length === 8 && hex.endsWith('ff')) return `#${hex.slice(0, 6)}`;
  return `#${hex}`;
}

function checkTheme(
  theme: unknown,
  errors: string[],
): AddonManifest['contributes']['theme'] {
  if (!isObject(theme)) {
    errors.push('contributes.theme: must be an object');
    return undefined;
  }
  const out: NonNullable<AddonManifest['contributes']['theme']> = {};
  for (const key of Object.keys(theme))
    if (!['name', 'light', 'dark'].includes(key))
      errors.push(`contributes.theme.${key}: unknown key`);
  if (theme.name !== undefined) {
    if (typeof theme.name === 'string') out.name = theme.name;
    else errors.push('contributes.theme.name: must be a string');
  }
  for (const mode of ['light', 'dark'] as const) {
    const colors = theme[mode];
    if (colors === undefined) continue;
    if (!isObject(colors)) {
      errors.push(`contributes.theme.${mode}: must be an object of colours`);
      continue;
    }
    const palette: Palette = {};
    for (const [key, value] of Object.entries(colors)) {
      const color = typeof value === 'string' ? normalizeColor(value) : null;
      if (!(PALETTE_FIELDS as readonly string[]).includes(key))
        errors.push(`contributes.theme.${mode}.${key}: unknown key`);
      else if (!color)
        errors.push(`contributes.theme.${mode}.${key}: not a colour`);
      else palette[key as keyof Palette] = color;
    }
    out[mode] = palette;
  }
  if (!out.light && !out.dark)
    errors.push('contributes.theme: give at least one of "light" or "dark"');
  return out;
}

/**
 * What in [css] could reach beyond the page: @import, and url() or
 * image-set() with anything but a data: URL. CSS escapes outside strings are
 * refused too, as they could spell either.
 */
export function cssProblems(css: string): string[] {
  const problems: string[] = [];
  const code = css.replace(/\/\*[\s\S]*?\*\//g, '');
  if (/@import/i.test(code)) problems.push('@import is not allowed');
  if (
    /url\(\s*(?!["']?\s*data:)/i.test(code) ||
    /image-set\(\s*["'](?!\s*data:)/i.test(code)
  )
    problems.push('url() may only hold a data: URL');
  const outsideStrings = code.replace(
    /"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'/g,
    '""',
  );
  if (/\\[0-9a-f]/i.test(outsideStrings))
    problems.push('escapes like \\75 are only allowed inside strings');
  return problems;
}

/** Checks a manifest and its files, listing every problem it finds. */
export function checkAddon(manifest: unknown, files: unknown): AddonCheck {
  if (!isObject(manifest))
    return { ok: false, errors: ['addon.json must be a JSON object'] };
  const errors: string[] = [];
  for (const key of Object.keys(manifest))
    if (!TOP_LEVEL.includes(key)) errors.push(unknownKey(key, key));

  const string = (key: string, max: number, required: boolean) => {
    const value = manifest[key];
    if (value === undefined) {
      if (required) errors.push(`${key}: missing`);
      return undefined;
    }
    if (typeof value !== 'string' || !value.trim()) {
      errors.push(`${key}: must be text`);
      return undefined;
    }
    if (value.length > max)
      errors.push(`${key}: longer than ${max} characters`);
    return value;
  };
  const id = string('id', 100, true);
  if (id && !ID.test(id))
    errors.push(
      'id: use lower-case words with dots, like "dev.example.my-addon"',
    );
  const name = string('name', 60, true);
  const version = string('version', 40, true);
  if (version && !VERSION.test(version))
    errors.push('version: use a version like "1.0.0"');
  const description = string('description', 300, false);
  const author = string('author', 100, false);
  const homepage = string('homepage', 300, false);
  if (homepage && !/^https:\/\/\S+$/.test(homepage))
    errors.push('homepage: must be an https:// address');

  const api = manifest.anchorApi;
  if (api === undefined) errors.push('anchorApi: missing; use 1');
  else if (typeof api !== 'number' || !Number.isInteger(api) || api < 1)
    errors.push('anchorApi: must be a whole number, such as 1');
  else if (api > ANCHOR_API)
    errors.push(`anchorApi ${api}: needs a newer Anchor+`);

  const fileMap = isObject(files) ? files : {};
  if (!isObject(files)) errors.push('files: must be an object of file texts');
  const contributes: AddonManifest['contributes'] = {};
  const given = manifest.contributes;
  if (!isObject(given)) errors.push('contributes: missing');
  else {
    for (const key of Object.keys(given))
      if (!CONTRIBUTES.includes(key))
        errors.push(unknownKey(`contributes.${key}`, key));
    if (given.theme !== undefined)
      contributes.theme = checkTheme(given.theme, errors);
    if (given.styles !== undefined) {
      if (
        !Array.isArray(given.styles) ||
        !given.styles.every((path) => typeof path === 'string')
      )
        errors.push(
          'contributes.styles: must be a list of files, like ["style.css"]',
        );
      else {
        for (const path of given.styles) {
          const text = fileMap[path];
          if (!STYLE_PATH.test(path))
            errors.push(
              `contributes.styles: "${path}" must be a .css file in the addon`,
            );
          else if (typeof text !== 'string')
            errors.push(`contributes.styles: "${path}" is not in the addon`);
          else
            for (const problem of cssProblems(text))
              errors.push(`${path}: ${problem}`);
        }
        contributes.styles = given.styles;
      }
    }
    if (!contributes.theme && !contributes.styles?.length && !errors.length)
      errors.push('contributes: give a theme or styles');
  }

  // Only the files the addon uses are kept.
  const used: Record<string, string> = {};
  for (const path of contributes.styles ?? []) {
    const text = fileMap[path];
    if (typeof text === 'string') used[path] = text;
  }
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
