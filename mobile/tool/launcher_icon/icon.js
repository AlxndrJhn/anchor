// The app icon: a note card, tilted on a deep sea teal, with a title line and
// an anchor whose ring is the "+" of Anchor+, on a 1024 by 1024 canvas.
// render.js draws every platform's images from it; the Android launcher
// layers (res/drawable/ic_launcher_*.xml), the web app's AnchorLogo
// (web/components/layout/anchor-logo.tsx) and the Flutter app's
// (lib/core/widgets/anchor_logo.dart) draw the same shapes themselves.

const themes = {
  light: { sea: ['#13687a', '#0b3b4a'], card: '#f4f1e8', line: '#cfd8d6', anchor: '#0b3b4a', plus: '#d9961c' },
  dark: { sea: ['#0f4f5e', '#06222b'], card: '#dfe3df', line: '#bcc6c4', anchor: '#0b3b4a', plus: '#d9961c' },
  // iOS tints a grey icon on black: the anchor and the + are the brightest.
  tinted: { sea: ['#000000', '#000000'], card: '#4a4a4a', line: '#6a6a6a', anchor: '#e6e6e6', plus: '#ffffff' },
};

// The card and everything on it turn 6 degrees left around this point.
const tilt = 'rotate(-6 512 520)';
const card = { x: 196, y: 150, width: 632, height: 740, rx: 80 };
const line = { x: 290, y: 236, width: 300, height: 44, rx: 22 };
const stroke = 47.5;
// The shank, the arms (radius 158.4, around the shank's foot) and their flukes.
const anchor = 'M512,534.6V772.2M353.6,613.8A158.4,158.4 0 0 0 670.4,613.8M353.6,613.8H401.1M670.4,613.8H622.9';
// The ring, above the shank.
const plus = 'M512,407.8V518.7M456.6,463.3H567.4';

/** CSS for the icon's colours; `auto` follows the system's dark mode. */
function style(theme) {
  const rules = (c) => `.s0{stop-color:${c.sea[0]}}.s1{stop-color:${c.sea[1]}}`
    + `.card{fill:${c.card}}.line{fill:${c.line}}.anchor{stroke:${c.anchor}}.plus{stroke:${c.plus}}`;
  return theme === 'auto'
    ? rules(themes.light) + `@media (prefers-color-scheme:dark){${rules(themes.dark)}}`
    : rules(themes[theme]);
}

const rect = (r, cls) => `<rect x="${r.x}" y="${r.y}" width="${r.width}" height="${r.height}" rx="${r.rx}" class="${cls}"/>`;

/**
 * The icon as an SVG: `theme` is light, dark, tinted or auto; `rounded`
 * clips it to the rounded square the web and desktop icons show, where iOS
 * and Android's launchers round a full square themselves.
 */
function icon({ theme = 'light', rounded = false } = {}) {
  const clip = rounded
    ? '<clipPath id="outline"><rect width="1024" height="1024" rx="256"/></clipPath>'
    : '';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"><title>Anchor+</title>'
    + `<style>${style(theme)}</style>`
    + '<defs>'
    + '<linearGradient id="sea" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="1024" y2="1024"><stop offset="0" class="s0"/><stop offset="1" class="s1"/></linearGradient>'
    + clip
    + '</defs>'
    + `<g${rounded ? ' clip-path="url(#outline)"' : ''}>`
    + '<path d="M0,0H1024V1024H0Z" fill="url(#sea)"/>'
    + `<g transform="${tilt}">`
    + rect(card, 'card') + rect(line, 'line')
    + `<g fill="none" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">`
    + `<path d="${anchor}" class="anchor"/>`
    + `<path d="${plus}" class="plus"/>`
    + '</g></g></g></svg>';
}

module.exports = { icon, themes };
