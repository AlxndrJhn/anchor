import type { NextConfig } from "next";
import packageJson from "./package.json";

// ANCHOR_MODE=local or demo builds a static site that needs no server (see
// lib/local-backend/mode.ts), served from BASE_PATH, e.g. GitHub Pages.
const mode = process.env.ANCHOR_MODE;
const isStatic = mode === "local" || mode === "demo";
const basePath = process.env.BASE_PATH ?? "";

const nextConfig: NextConfig = {
  output: isStatic ? "export" : "standalone",
  ...(isStatic ? { basePath, images: { unoptimized: true } } : {}),
  env: {
    NEXT_PUBLIC_APP_VERSION: packageJson.version,
    NEXT_PUBLIC_ANCHOR_MODE: isStatic ? mode : "server",
    NEXT_PUBLIC_BASE_PATH: isStatic ? basePath : "",
  },
  experimental: {
    proxyClientMaxBodySize: "50mb",
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
