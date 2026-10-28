/**
 * How this build of the web app runs. A normal build talks to an Anchor
 * server. The static builds published on GitHub Pages have none: "local"
 * keeps everything in this browser's storage, "demo" keeps it in memory, so
 * a reload starts over, and plays the feature demos.
 */
export type AppMode = "server" | "local" | "demo";

export const appMode: AppMode =
  process.env.NEXT_PUBLIC_ANCHOR_MODE === "local" ||
  process.env.NEXT_PUBLIC_ANCHOR_MODE === "demo"
    ? process.env.NEXT_PUBLIC_ANCHOR_MODE
    : "server";

/** Served without a server: the app answers its own requests. */
export const isServerless = appMode !== "server";

export const isDemo = appMode === "demo";

/** Where the app is served from, e.g. "/anchor" on GitHub Pages. */
export const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? "";

/** A file in public/, at the address it is served from. */
export const publicPath = (path: string) => `${basePath}${path}`;
