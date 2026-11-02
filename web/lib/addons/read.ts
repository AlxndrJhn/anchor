import { strFromU8, unzipSync } from "fflate";
import {
  type AddonCheck,
  checkAddon,
  MAX_ADDON_SIZE,
  STYLE_PATH,
} from "./manifest";

const TEXT_FILE = /\.(?:json|css)$/i;

/**
 * An addon from a .zip (addon.json at its top, or in one folder) or from an
 * addon.json alone, which can then only bring a theme.
 */
export function readAddon(name: string, bytes: Uint8Array): AddonCheck {
  if (bytes.length > 4 * MAX_ADDON_SIZE)
    return { ok: false, errors: ["The file is too large to be an addon"] };
  if (!/\.zip$/i.test(name) && bytes[0] !== 0x50) {
    const text = strFromU8(bytes);
    try {
      return checkAddon(JSON.parse(text), {});
    } catch {
      return {
        ok: false,
        errors: ["Choose an addon's .zip or its addon.json"],
      };
    }
  }
  let entries: Record<string, Uint8Array>;
  try {
    entries = unzipSync(bytes, { filter: (file) => TEXT_FILE.test(file.name) });
  } catch {
    return { ok: false, errors: ["The .zip can't be opened"] };
  }
  const manifestPath = Object.keys(entries)
    .filter((path) => /(?:^|\/)addon\.json$/.test(path))
    .sort((a, b) => a.split("/").length - b.split("/").length)[0];
  if (!manifestPath)
    return { ok: false, errors: ["The .zip has no addon.json"] };
  const root = manifestPath.slice(0, -"addon.json".length);
  let manifest: unknown;
  try {
    manifest = JSON.parse(strFromU8(entries[manifestPath]));
  } catch (error) {
    return {
      ok: false,
      errors: [
        `addon.json is not valid JSON: ${error instanceof Error ? error.message : error}`,
      ],
    };
  }
  const files: Record<string, string> = {};
  for (const [path, data] of Object.entries(entries))
    if (path.startsWith(root) && path !== manifestPath)
      files[path.slice(root.length)] = strFromU8(data);
  return checkAddon(manifest, files);
}

const CANT_DOWNLOAD =
  "Couldn't download it. The address may be wrong, or its site doesn't let other sites download from it; download the file and choose it instead.";

async function download(url: string): Promise<Uint8Array | string> {
  let response: Response;
  try {
    response = await fetch(url, { credentials: "omit" });
  } catch {
    return CANT_DOWNLOAD;
  }
  if (!response.ok) return `${url} answered ${response.status}`;
  return new Uint8Array(await response.arrayBuffer());
}

/**
 * An addon from an address that answers with its .zip or its addon.json. The
 * style files an addon.json names are downloaded from beside it.
 */
export async function fetchAddon(url: string): Promise<AddonCheck> {
  if (!/^https:\/\//.test(url))
    return { ok: false, errors: ["Use an https:// address"] };
  const bytes = await download(url);
  if (typeof bytes === "string") return { ok: false, errors: [bytes] };
  const name = new URL(url).pathname.split("/").pop() ?? "";
  if (/\.zip$/i.test(name) || bytes[0] === 0x50) return readAddon(name, bytes);
  let manifest: unknown;
  try {
    manifest = JSON.parse(strFromU8(bytes));
  } catch {
    return {
      ok: false,
      errors: ["The address answered with neither a .zip nor an addon.json"],
    };
  }
  const contributes = (manifest as { contributes?: { styles?: unknown } })
    ?.contributes;
  const styles = Array.isArray(contributes?.styles) ? contributes.styles : [];
  const files: Record<string, string> = {};
  for (const path of styles) {
    if (typeof path !== "string" || !STYLE_PATH.test(path)) continue;
    const style = await download(new URL(path, url).href);
    if (typeof style === "string") return { ok: false, errors: [style] };
    files[path] = strFromU8(style);
  }
  return checkAddon(manifest, files);
}
