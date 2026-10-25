#!/usr/bin/env node
// Writes the colour schemes in design/schemes/schemes.json out for the web
// and Android. `--check` fails when a generated file is out of date.
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const source = JSON.parse(
  readFileSync(join(root, "design/schemes/schemes.json"), "utf8"),
);
const header = (comment) =>
  `${comment} Generated from design/schemes/schemes.json by design/build/schemes.mjs. Do not edit by hand.\n`;

const FIELDS = [
  "background",
  "card",
  "sidebar",
  "muted",
  "foreground",
  "mutedForeground",
  "accent",
  "accentStrong",
  "accentInk",
  "border",
  "divider",
  "input",
  "destructive",
];

for (const scheme of [
  ...source.schemes,
  { id: "lofi", light: source.lofi.light, dark: source.lofi.dark },
])
  for (const mode of ["light", "dark"])
    for (const field of FIELDS)
      if (!/^#[0-9A-Fa-f]{6}$/.test(scheme[mode]?.[field] ?? ""))
        throw new Error(`${scheme.id}.${mode}.${field} must be #RRGGBB`);

/** The palette as the web's colour variables. */
const cssVars = (p) =>
  Object.entries({
    background: p.background,
    foreground: p.foreground,
    card: p.card,
    popover: p.card,
    primary: p.foreground,
    muted: p.muted,
    "muted-foreground": p.mutedForeground,
    accent: p.accent,
    "accent-strong": p.accentStrong,
    "accent-ink": p.accentInk,
    destructive: p.destructive,
    border: p.border,
    divider: p.divider,
    input: p.input,
    ring: p.accentStrong,
    sidebar: p.sidebar,
    "sidebar-accent": p.card,
    inverse: p.foreground,
    "inverse-foreground": p.background,
    "inverse-link": p.accent,
    "inverse-danger": p.destructive,
  })
    .map(([name, value]) => `  --${name}: ${value.toLowerCase()};`)
    .join("\n");

const css = [
  header("/*").replace("\n", " */\n"),
  ...source.schemes.flatMap((s) => [
    `html[data-scheme="${s.id}"].light {\n${cssVars(s.light)}\n}`,
    `html[data-scheme="${s.id}"].dark {\n${cssVars(s.dark)}\n}`,
  ]),
  "/* Lo-fi draws in its own greys, whatever the scheme. */",
  `html[data-style="lofi"].light {\n${cssVars(source.lofi.light)}\n}`,
  `html[data-style="lofi"].dark {\n${cssVars(source.lofi.dark)}\n}`,
  "",
].join("\n\n");

const swatch = (p) =>
  `{ background: "${p.background}", card: "${p.card}", foreground: "${p.foreground}", accent: "${p.accent}" }`;
const ts = `${header("//")}
export interface SchemeSwatch {
  background: string;
  card: string;
  foreground: string;
  accent: string;
}

export interface ColorScheme {
  id: string;
  name: string;
  light: SchemeSwatch;
  dark: SchemeSwatch;
}

export const COLOR_SCHEMES: ColorScheme[] = [
${source.schemes
  .map(
    (s) =>
      `  {\n    id: "${s.id}",\n    name: "${s.name}",\n    light: ${swatch(s.light)},\n    dark: ${swatch(s.dark)},\n  },`,
  )
  .join("\n")}
];
`;

const dartColor = (hex) => `Color(0xFF${hex.slice(1).toUpperCase()})`;
const dartPalette = (p) =>
  `SchemePalette(\n${FIELDS.map((f) => `      ${f}: ${dartColor(p[f])},`).join("\n")}\n    )`;
const dart = `${header("//")}
import 'package:flutter/widgets.dart';

/// One mode of a colour scheme, in the web app's terms.
class SchemePalette {
  const SchemePalette({
${FIELDS.map((f) => `    required this.${f},`).join("\n")}
  });

${FIELDS.map((f) => `  final Color ${f};`).join("\n")}
}

/// A colour scheme offered in Settings, with its light and dark palettes.
class AppScheme {
  const AppScheme({
    required this.id,
    required this.name,
    required this.light,
    required this.dark,
  });

  final String id;
  final String name;
  final SchemePalette light;
  final SchemePalette dark;

  SchemePalette of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// The schemes besides Anchor's own, in the order Settings lists them.
const appSchemes = <AppScheme>[
${source.schemes
  .map(
    (s) =>
      `  AppScheme(\n    id: '${s.id}',\n    name: '${s.name}',\n    light: ${dartPalette(s.light)},\n    dark: ${dartPalette(s.dark)},\n  ),`,
  )
  .join("\n")}
];

/// The Lo-fi style's own greys, used whatever the scheme.
const lofiScheme = AppScheme(
  id: 'lofi',
  name: 'Lo-fi',
  light: ${dartPalette(source.lofi.light)},
  dark: ${dartPalette(source.lofi.dark)},
);
`;

const outputs = {
  "web/app/styles/schemes.css": css,
  "web/lib/design/schemes.ts": ts,
  "mobile/lib/core/theme/tokens/app_schemes.dart": dart,
};

const check = process.argv.includes("--check");
let stale = false;
for (const [path, content] of Object.entries(outputs)) {
  const file = join(root, path);
  if (check) {
    let current = "";
    try {
      current = readFileSync(file, "utf8");
    } catch {}
    // Dart files are compared without layout, so `dart format` may run on them.
    const same = path.endsWith(".dart")
      ? current.replace(/[\s,]/g, "") === content.replace(/[\s,]/g, "")
      : current === content;
    if (!same) {
      console.error(`${path} is out of date: run node design/build/schemes.mjs`);
      stale = true;
    }
  } else writeFileSync(file, content);
}
if (stale) process.exit(1);
console.log(check ? "Scheme files are up to date." : "Wrote the scheme files.");
