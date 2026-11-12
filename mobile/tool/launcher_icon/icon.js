// The app icon: an anchor whose ring is the "+" of Anchor+, in sail white and
// brass on deep sea teal, on a 1024 by 1024 canvas. render.js draws every
// platform's images from it; the Android launcher layers
// (res/drawable/ic_launcher_*.xml), the web app's AnchorLogo
// (web/components/layout/anchor-logo.tsx) and the Flutter app's
// (lib/core/widgets/anchor_logo.dart) draw the same shapes themselves.

const themes = {
  light: { sea: ['#13687a', '#0b3b4a'], anchor: '#f4f1e8', plus: '#f2b544' },
  dark: { sea: ['#0f4f5e', '#06222b'], anchor: '#e9ece8', plus: '#f2b544' },
  // iOS tints a grey icon on black: the + is the brightest.
  tinted: { sea: ['#000000', '#000000'], anchor: '#c8c8c8', plus: '#f0f0f0' },
};

const stroke = 72;
// The shank, the arms (radius 240, around the shank's foot) and their flukes.
const anchor = 'M512,428V788M272,548A240,240 0 0 0 752,548M272,548H344M752,548H680';
// The ring, above the shank.
const plus = 'M512,236V404M428,320H596';

/** CSS for the icon's colours; `auto` follows the system's dark mode. */
function style(theme) {
  const rules = (c) => `.s0{stop-color:${c.sea[0]}}.s1{stop-color:${c.sea[1]}}`
    + `.anchor{stroke:${c.anchor}}.plus{stroke:${c.plus}}`;
  return theme === 'auto'
    ? rules(themes.light) + `@media (prefers-color-scheme:dark){${rules(themes.dark)}}`
    : rules(themes[theme]);
}

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
    + `<g fill="none" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">`
    + `<path d="${anchor}" class="anchor"/>`
    + `<path d="${plus}" class="plus"/>`
    + '</g></g></svg>';
}

module.exports = { icon, themes };
