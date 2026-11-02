/**
 * Puts the addons that are on into the page: their themes' colours, then
 * their CSS, in one <style>. What it puts there is also kept in this browser,
 * so addonsScript can put it there before the first paint.
 */

import { THEME_MODES } from "@/lib/design/custom-theme";
import { PALETTE_CSS_VARS } from "@/lib/design/schemes";
import type { AddonManifest } from "./manifest";

export const ADDONS_STYLE_ID = "addons";
const CACHE_KEY = "addons-css";
const SAFE_KEY = "addons-safe";

export interface AppliedAddon {
  enabled: boolean;
  manifest: AddonManifest;
  files: Record<string, string>;
}

/**
 * The selector an addon theme's colours go under. It outranks the schemes'
 * `html[data-scheme="…"].dark`, gives way to the person's own custom theme
 * (`:root[data-custom-theme]…`), and leaves Lo-fi to its own greys.
 */
export const addonThemeSelector = (mode: string) =>
  `html[data-addon-theme]:not([data-style="lofi"]).${mode}`;

/** The CSS of every addon that is on, in the order they were installed. */
export function addonsCss(addons: readonly AppliedAddon[]): {
  css: string;
  theme: boolean;
} {
  const parts: string[] = [];
  let theme = false;
  for (const addon of addons) {
    if (!addon.enabled) continue;
    const { id, contributes } = addon.manifest;
    parts.push(`/* ${id.replace(/\*\//g, "")} */`);
    for (const mode of THEME_MODES) {
      const colors = contributes.theme?.[mode];
      if (!colors) continue;
      const declarations = Object.entries(PALETTE_CSS_VARS)
        .filter(([, field]) => colors[field])
        .map(([name, field]) => `--${name}:${colors[field]};`)
        .join("");
      if (!declarations) continue;
      theme = true;
      parts.push(`${addonThemeSelector(mode)}{${declarations}}`);
    }
    for (const path of contributes.styles ?? [])
      parts.push(addon.files[path] ?? "");
  }
  return { css: parts.length ? parts.join("\n") : "", theme };
}

/** Whether this tab was opened with ?safe, which leaves every addon off. */
export function isSafeMode(): boolean {
  try {
    if (new URLSearchParams(location.search).has("safe"))
      sessionStorage.setItem(SAFE_KEY, "1");
    return sessionStorage.getItem(SAFE_KEY) === "1";
  } catch {
    return false;
  }
}

/** Leaves safe mode, reloading the page without ?safe. */
export function leaveSafeMode() {
  try {
    sessionStorage.removeItem(SAFE_KEY);
  } catch {}
  const url = new URL(location.href);
  url.searchParams.delete("safe");
  location.replace(url);
}

/** Applies [addons] to the page and keeps them for the next load. */
export function applyAddons(addons: readonly AppliedAddon[]) {
  const html = document.documentElement;
  const { css, theme } = isSafeMode()
    ? { css: "", theme: false }
    : addonsCss(addons);
  let sheet = document.getElementById(ADDONS_STYLE_ID);
  if (css) {
    if (!sheet) {
      sheet = document.createElement("style");
      sheet.id = ADDONS_STYLE_ID;
      document.head.appendChild(sheet);
    }
    if (sheet.textContent !== css) sheet.textContent = css;
  } else sheet?.remove();
  if (theme) html.dataset.addonTheme = "";
  else delete html.dataset.addonTheme;
  if (isSafeMode()) return;
  try {
    if (css) localStorage.setItem(CACHE_KEY, JSON.stringify({ css, theme }));
    else localStorage.removeItem(CACHE_KEY);
  } catch {}
}

/**
 * Runs before the first paint, after appearanceScript, so addons don't flash
 * in on load. Safe mode leaves them out.
 */
export const addonsScript = `try{var q=new URLSearchParams(location.search).has("safe");if(q)sessionStorage.setItem("${SAFE_KEY}","1");if(!q&&sessionStorage.getItem("${SAFE_KEY}")!=="1"){var a=JSON.parse(localStorage.getItem("${CACHE_KEY}"));if(a&&typeof a.css==="string"){var s=document.createElement("style");s.id="${ADDONS_STYLE_ID}";s.textContent=a.css;document.head.appendChild(s);if(a.theme)document.documentElement.dataset.addonTheme=""}}}catch(e){}`;
