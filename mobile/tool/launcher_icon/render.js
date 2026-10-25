// Renders the Android launcher icon from parts.js. From mobile/:
//   NODE_PATH=$(npm root -g) node tool/launcher_icon/render.js /tmp/icon
// then copy drawable-*/ and mipmap-*/ into android/app/src/main/res/.
const { chromium } = require('playwright');
const fs = require('fs');
const parts = require(require('node:path').join(__dirname, 'parts.js'));
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  const shot = async (svgs, size, file, mask) => {
    const layers = svgs.map(s => `<div style="position:absolute;inset:0">${s.replace('<svg ', `<svg width="${size}" height="${size}" `)}</div>`).join('');
    const clip = mask === 'squircle' ? `border-radius:${size*0.3}px;overflow:hidden;` : mask === 'circle' ? 'border-radius:50%;overflow:hidden;' : '';
    await page.setViewportSize({ width: size, height: size });
    await page.setContent(`<html><body style="margin:0;background:transparent"><div style="position:relative;width:${size}px;height:${size}px;${clip}">${layers}</div></body></html>`);
    await page.screenshot({ path: file, omitBackground: true });
  };
  const out = process.argv[2];
  fs.mkdirSync(out, { recursive: true });
  // Adaptive layers: 108dp at each density.
  const dens = { mdpi: 1, hdpi: 1.5, xhdpi: 2, xxhdpi: 3, xxxhdpi: 4 };
  for (const [d, k] of Object.entries(dens)) {
    fs.mkdirSync(`${out}/drawable-${d}`, { recursive: true });
    fs.mkdirSync(`${out}/mipmap-${d}`, { recursive: true });
    await shot([parts.foreground], 108 * k, `${out}/drawable-${d}/ic_launcher_foreground.png`);
    await shot([parts.background], 108 * k, `${out}/drawable-${d}/ic_launcher_background.png`);
    await shot([parts.monochrome], 108 * k, `${out}/drawable-${d}/ic_launcher_monochrome.png`);
    // Legacy (pre-Android 8) icon: 48dp, the visible 72dp of the layers.
    const legacy = (s) => s.replace('viewBox="0 0 108 108"', 'viewBox="18 18 72 72"');
    for (const name of ['launcher_icon', 'ic_launcher'])
      await shot([legacy(parts.background), legacy(parts.foreground)], 48 * k, `${out}/mipmap-${d}/${name}.png`, 'squircle');
  }
  // Previews of the masks launchers use.
  const v = (s) => s.replace('viewBox="0 0 108 108"', 'viewBox="18 18 72 72"');
  await shot([v(parts.background), v(parts.foreground)], 512, `${out}/preview-squircle.png`, 'squircle');
  await shot([v(parts.background), v(parts.foreground)], 512, `${out}/preview-circle.png`, 'circle');
  await browser.close();
})();
