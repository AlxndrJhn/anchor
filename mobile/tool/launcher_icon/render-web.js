// Renders the web app's icons from the same layers as the Android launcher
// icon (parts.js). From mobile/:
//   NODE_PATH=$(npm root -g) node tool/launcher_icon/render-web.js
// Writes web/app/{favicon.ico,icon0.svg,icon1.png,apple-icon.png} and
// web/public/{anchor-mark.svg,web-app-manifest-{192x192,512x512}.png}.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const parts = require(path.join(__dirname, 'parts.js'));

const web = path.join(__dirname, '..', '..', '..', 'web');
// The part of the 108dp layers a launcher shows, as for Android's legacy icon.
const visible = (svg) => svg.replace('viewBox="0 0 108 108"', 'viewBox="18 18 72 72"');
const inner = (svg) => svg.replace(/^\s*<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');

/** One SVG of both layers; `rounded` clips it to a rounded square. */
function combined(viewBox, rounded) {
  const [x, y, w] = viewBox.split(' ').map(Number);
  const clip = rounded
    ? `<clipPath id="r"><rect x="${x}" y="${y}" width="${w}" height="${w}" rx="${w * 0.22}"/></clipPath>`
    : '';
  // Each layer keeps its own ids; the foreground's defs don't clash with the background's.
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}"><defs>${clip}</defs><g${rounded ? ' clip-path="url(#r)"' : ''}>${inner(parts.background)}${inner(parts.foreground)}</g></svg>`;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const png = async (svg, size, file) => {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(
      `<html><body style="margin:0;background:transparent">${svg.replace('<svg ', `<svg width="${size}" height="${size}" `)}</body></html>`,
    );
    await page.screenshot({ path: file, omitBackground: true });
  };
  // Install icons are maskable: the whole 108dp canvas, with the pad inside
  // the safe zone, as Android's adaptive icon.
  await png(combined('0 0 108 108', false), 192, path.join(web, 'public/web-app-manifest-192x192.png'));
  await png(combined('0 0 108 108', false), 512, path.join(web, 'public/web-app-manifest-512x512.png'));
  // iOS rounds the corners itself.
  await png(combined('18 18 72 72', false), 180, path.join(web, 'app/apple-icon.png'));
  await png(combined('18 18 72 72', true), 96, path.join(web, 'app/icon1.png'));
  // Browser tabs are tiny: a closer crop keeps the pad readable.
  const tab = combined('23 21 62 62', true);
  fs.writeFileSync(path.join(web, 'app/icon0.svg'), tab);
  // The logo in the app's sidebar and sign-in page.
  fs.writeFileSync(path.join(web, 'public/anchor-mark.svg'), tab);

  // favicon.ico: 16, 32 and 48 px PNGs in one ICO.
  const sizes = [16, 32, 48];
  const images = [];
  for (const size of sizes) {
    const file = path.join(require('node:os').tmpdir(), `anchor-fav-${size}.png`);
    await png(tab, size, file);
    images.push(fs.readFileSync(file));
  }
  const header = Buffer.alloc(6 + 16 * sizes.length);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  sizes.forEach((size, i) => {
    const at = 6 + 16 * i;
    header.writeUInt8(size, at);
    header.writeUInt8(size, at + 1);
    header.writeUInt16LE(1, at + 4);
    header.writeUInt16LE(32, at + 6);
    header.writeUInt32LE(images[i].length, at + 8);
    header.writeUInt32LE(offset, at + 12);
    offset += images[i].length;
  });
  fs.writeFileSync(path.join(web, 'app/favicon.ico'), Buffer.concat([header, ...images]));
  await browser.close();
  console.log('Wrote the web icons.');
})();
