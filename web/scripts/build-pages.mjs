// Builds the GitHub Pages site into out/: the app at BASE_PATH, keeping notes
// in the browser, and the demo at BASE_PATH/demo, keeping them in memory.
//   BASE_PATH=/anchor pnpm build:pages
import { execFileSync } from "node:child_process";
import { renameSync, rmSync } from "node:fs";
import { join } from "node:path";

const web = join(import.meta.dirname, "..");
const base = (process.env.BASE_PATH ?? "").replace(/\/+$/, "");
const out = join(web, "out");
const demoOut = join(web, ".pages-demo");

function build(mode, basePath) {
  const env = { ...process.env, ANCHOR_MODE: mode, BASE_PATH: basePath };
  execFileSync("pnpm", ["exec", "next", "build"], {
    cwd: web,
    env,
    stdio: "inherit",
  });
  execFileSync("node", [join(web, "scripts", "static-site.mjs")], {
    cwd: web,
    env,
    stdio: "inherit",
  });
}

rmSync(demoOut, { recursive: true, force: true });
build("demo", `${base}/demo`);
renameSync(out, demoOut);
build("local", base);
renameSync(demoOut, join(out, "demo"));
// GitHub Pages would otherwise skip the folders whose names start with "_".
execFileSync("touch", [join(out, ".nojekyll")]);
console.log(`GitHub Pages site in ${out}`);
