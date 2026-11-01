// Renders every platform's app icon images from icon.js. From mobile/, with
// Playwright installed (CHROME may name a Chromium to use instead of its own):
//   NODE_PATH=$(npm root -g) node tool/launcher_icon/render.js
//
// Writes:
//   Android   mipmap-*/launcher_icon.png (the pre-Android 8 icon; newer ones
//             draw res/drawable/ic_launcher_*.xml) and the splash images
//             flutter_native_splash makes from assets/icons/splash_logo*.png
//   iOS       the light, dark and tinted 1024px icons, and the launch images
//   macOS     app_icon_*.png, on Apple's icon grid
//   Windows   runner/resources/app_icon.ico
//   web/      the Flutter web build's favicon and install icons
//   ../web    favicon.ico, icon0.svg (the tab, light or dark), icon1.png,
//             apple-icon.png, the install icons and public/icons/anchor_icon.png
//             (the README's picture and the desktop app's icon)
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const { icon } = require(path.join(__dirname, 'icon.js'));

const mobile = path.join(__dirname, '..', '..');
const web = path.join(mobile, '..', 'web');
const res = path.join(mobile, 'android/app/src/main/res');
const at = (...parts) => path.join(mobile, ...parts);
const densities = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };

/** PNGs in one .ico, largest last. */
function ico(images, sizes) {
  const header = Buffer.alloc(6 + 16 * sizes.length);
  header.writeUInt16LE(1, 2);
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  sizes.forEach((size, i) => {
    const entry = 6 + 16 * i;
    header.writeUInt8(size >= 256 ? 0 : size, entry);
    header.writeUInt8(size >= 256 ? 0 : size, entry + 1);
    header.writeUInt16LE(1, entry + 4);
    header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(images[i].length, entry + 8);
    header.writeUInt32LE(offset, entry + 12);
    offset += images[i].length;
  });
  return Buffer.concat([header, ...images]);
}

(async () => {
  const browser = await chromium.launch({ executablePath: process.env.CHROME || undefined });
  const page = await browser.newPage();
  /** Draws `html` on a transparent `size` square; writes it to `file` if given. */
  const shot = async (html, size, file) => {
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(`<html><body style="margin:0;background:transparent">${html}</body></html>`);
    const png = await page.screenshot({ omitBackground: true });
    if (file) fs.writeFileSync(file, png);
    return png;
  };
  const sized = (svg, size) => svg.replace('<svg ', `<svg width="${size}" height="${size}" style="display:block" `);
  const square = (size, file, theme = 'light') => shot(sized(icon({ theme }), size), size, file);
  const rounded = (size, file, theme = 'light') => shot(sized(icon({ theme, rounded: true }), size), size, file);

  // Android: the legacy icon, and the splash images flutter_native_splash
  // makes, at each density.
  for (const [d, k] of Object.entries(densities)) {
    await rounded(48 * k, path.join(res, `mipmap-${d}/launcher_icon.png`));
    await rounded(128 * k, path.join(res, `drawable-${d}/splash.png`));
    for (const [dir, theme] of [[`drawable-${d}`, 'light'], [`drawable-night-${d}`, 'dark']]) {
      // Android 12+ shows the middle 2/3 of the image in a circle.
      const size = 288 * k;
      await shot(
        `<div style="width:${size}px;height:${size}px;display:grid;place-items:center">`
          + `<div style="width:${size * 2 / 3}px;height:${size * 2 / 3}px;border-radius:50%;overflow:hidden">${sized(icon({ theme }), size * 2 / 3)}</div></div>`,
        size,
        path.join(res, dir, 'android12splash.png'),
      );
    }
  }
  // flutter_native_splash's sources, so a rerun of it makes the same images.
  await rounded(512, at('assets/icons/splash_logo.png'));
  for (const [name, theme] of [['splash_logo_android12.png', 'light'], ['splash_logo_android12_dark.png', 'dark']]) {
    await shot(
      '<div style="width:1152px;height:1152px;display:grid;place-items:center">'
        + `<div style="width:768px;height:768px;border-radius:50%;overflow:hidden">${sized(icon({ theme }), 768)}</div></div>`,
      1152,
      at('assets/icons', name),
    );
  }

  // iOS rounds the corners itself.
  const ios = at('ios/Runner/Assets.xcassets');
  await square(1024, path.join(ios, 'AppIcon.appiconset/Icon-App-1024x1024@1x.png'));
  await square(1024, path.join(ios, 'AppIcon.appiconset/Icon-App-Dark-1024x1024@1x.png'), 'dark');
  await square(1024, path.join(ios, 'AppIcon.appiconset/Icon-App-Tinted-1024x1024@1x.png'), 'tinted');
  for (const [suffix, k] of [['', 1], ['@2x', 2], ['@3x', 3]])
    await rounded(128 * k, path.join(ios, `LaunchImage.imageset/LaunchImage${suffix}.png`));

  // macOS: the rounded square is 824 of 1024, with a soft shadow below.
  for (const size of [16, 32, 64, 128, 256, 512, 1024]) {
    const inset = size * 100 / 1024;
    await shot(
      `<div style="width:${size}px;height:${size}px;display:grid;place-items:center">`
        + `<div style="width:${size - 2 * inset}px;height:${size - 2 * inset}px;border-radius:22.5%;overflow:hidden;`
        + `box-shadow:0 ${size * 10 / 1024}px ${size * 20 / 1024}px rgba(0,0,0,.3)">${sized(icon(), size - 2 * inset)}</div></div>`,
      size,
      at(`macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png`),
    );
  }

  // Windows.
  const winSizes = [16, 24, 32, 48, 64, 128, 256];
  const winImages = [];
  for (const size of winSizes) winImages.push(await rounded(size));
  fs.writeFileSync(at('windows/runner/resources/app_icon.ico'), ico(winImages, winSizes));

  // The Flutter web build: maskable icons are the full square, which keeps
  // the anchor and the + inside the safe circle.
  await rounded(16, at('web/favicon.png'));
  for (const size of [192, 512]) {
    await rounded(size, at(`web/icons/Icon-${size}.png`));
    await square(size, at(`web/icons/Icon-maskable-${size}.png`));
  }

  // The web app, and the desktop app that wraps it.
  fs.writeFileSync(path.join(web, 'app/icon0.svg'), icon({ theme: 'auto', rounded: true }));
  await rounded(96, path.join(web, 'app/icon1.png'));
  await square(180, path.join(web, 'app/apple-icon.png'));
  for (const size of [192, 512]) {
    await rounded(size, path.join(web, `public/web-app-manifest-any-${size}x${size}.png`));
    await square(size, path.join(web, `public/web-app-manifest-${size}x${size}.png`));
  }
  await rounded(1024, path.join(web, 'public/icons/anchor_icon.png'));
  const favSizes = [16, 32, 48];
  const favImages = [];
  for (const size of favSizes) favImages.push(await rounded(size));
  fs.writeFileSync(path.join(web, 'app/favicon.ico'), ico(favImages, favSizes));

  await browser.close();
  console.log('Wrote the icons.');
})();
