import type { NextConfig } from "next";
import packageJson from "./package.json";

// ANCHOR_MODE=local or demo builds a static site that needs no server (see
// lib/local-backend/mode.ts), served from BASE_PATH, e.g. GitHub Pages.
const mode = process.env.ANCHOR_MODE;
const isStatic = mode === "local" || mode === "demo";
const basePath = process.env.BASE_PATH ?? "";
// The Anchor+ release, e.g. 0.17.2.62 for fork-0.17.2.62, set by
// release-fork.yml; a build outside a release shows the app version.
const appVersion = process.env.ANCHOR_VERSION || packageJson.version;

const nextConfig: NextConfig = {
  output: isStatic ? "export" : "standalone",
  ...(isStatic ? { basePath, images: { unoptimized: true } } : {}),
  env: {
    NEXT_PUBLIC_APP_VERSION: appVersion,
    NEXT_PUBLIC_ANCHOR_MODE: isStatic ? mode : "server",
    NEXT_PUBLIC_BASE_PATH: isStatic ? basePath : "",
  },
  experimental: {
    // Above the server's 50 MB attachment limit, by the multipart wrapping
    // and then some: a file over the limit reaches the server, which answers
    // 413, instead of being cut off here and failing with a 500.
    proxyClientMaxBodySize: "55mb",
  },
  ...(isStatic
    ? {}
    : {
        rewrites: async () => {
          const serverUrl = process.env.SERVER_URL || "http://127.0.0.1:3001";
          return [
            {
              source: "/api/:path*",
              destination: `${serverUrl}/api/:path*`,
            },
            {
              source: "/uploads/:path*",
              destination: `${serverUrl}/uploads/:path*`,
            },
          ];
        },
      }),
};

export default nextConfig;
