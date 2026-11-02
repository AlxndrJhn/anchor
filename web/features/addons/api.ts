import { HTTPError } from "ky";
import type { AddonPackage } from "@/lib/addons/manifest";
import { api } from "@/lib/api/client";
import type { Addon } from "./types";

/** The addons, or null from a server without them, as upstream Anchor's. */
export async function getAddons(): Promise<Addon[] | null> {
  try {
    return await api.get("api/addons").json<Addon[]>();
  } catch (error) {
    if (error instanceof HTTPError && error.response.status === 404)
      return null;
    throw error;
  }
}

/** Installs an addon, or updates the one with its id. */
export async function installAddon(addon: AddonPackage): Promise<Addon> {
  return api.post("api/addons", { json: addon }).json<Addon>();
}

export async function setAddonEnabled(
  id: string,
  enabled: boolean,
): Promise<Addon> {
  return api.patch(`api/addons/${id}`, { json: { enabled } }).json<Addon>();
}

export async function removeAddon(id: string): Promise<void> {
  await api.delete(`api/addons/${id}`);
}
