import type { AddonManifest } from "@/lib/addons/manifest";

/** An installed addon, as GET api/addons lists it. */
export interface Addon {
  id: string;
  addonId: string;
  version: string;
  enabled: boolean;
  manifest: AddonManifest;
  files: Record<string, string>;
  createdAt: string;
  updatedAt: string;
}
