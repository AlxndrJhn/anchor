// Renders the rest of the app's icon images from the launcher icon's layers
// (parts.js). From mobile/:
//   NODE_PATH=$(npm root -g) node tool/launcher_icon/render-assets.js
// then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
//
// Writes, under mobile/assets/icons/:
//   anchor_icon.png       1024px rounded icon for macOS, Windows and the
//                         Flutter web build
//   anchor_logo.png       384px rounded icon: the in-app logo, drawn at up
//                         to 100dp
//   app_icon_square.png   1024px full-bleed icon for iOS, which rounds it
//   splash_logo.png       512px rounded icon for the splash screen
//   splash_logo_android12[_dark].png  1152px canvas with the icon inside the
//                         768px circle Android 12+ shows, on the splash colour
// and web/public/icons/anchor_icon.png (the README's picture).
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const parts = require(path.join(__dirname, 'parts.js'));

const mobile = path.join(__dirname, '..', '..');
const web = path.join(mobile, '..', 'web');
const inner = (svg) => svg.replace(/^\s*<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');

function icon(rounded) {
  const clip = rounded ? '<clipPath id="r"><rect x="18" y="18" width="72" height="72" rx="15.8"/></clipPath>' : '';
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="18 18 72 72"><defs>${clip}</defs><g${rounded ? ' clip-path="url(#r)"' : ''}>${inner(parts.background)}${inner(parts.foreground)}</g></svg>`;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const render = async (html, size, file, transparent = true) => {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(`<html><body style="margin:0">${html}</body></html>`);
    await page.screenshot({ path: file, omitBackground: transparent });
  };
  const sized = (svg, size) => svg.replace('<svg ', `<svg width="${size}" height="${size}" `);

  await render(sized(icon(true), 1024), 1024, path.join(mobile, 'assets/icons/anchor_icon.png'));
  fs.copyFileSync(path.join(mobile, 'assets/icons/anchor_icon.png'), path.join(web, 'public/icons/anchor_icon.png'));
  await render(sized(icon(true), 384), 384, path.join(mobile, 'assets/icons/anchor_logo.png'));
  await render(sized(icon(false), 1024), 1024, path.join(mobile, 'assets/icons/app_icon_square.png'), false);
  await render(sized(icon(true), 512), 512, path.join(mobile, 'assets/icons/splash_logo.png'));
  for (const [name, colour] of [['splash_logo_android12.png', '#F0F4F8'], ['splash_logo_android12_dark.png', '#1C1E26']]) {
    // 540px fits inside the 768px circle with its corners.
    await render(
      `<div style="width:1152px;height:1152px;background:${colour};display:grid;place-items:center">${sized(icon(true), 540)}</div>`,
      1152,
      path.join(mobile, 'assets/icons', name),
      false,
    );
  }
  await browser.close();
  console.log('Wrote the icon assets.');
})();
