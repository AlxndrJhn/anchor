// The app icon, upstream's redesign (a note with an orange top, three lines
// and an anchor) with the "+" of Anchor+ beside the anchor's ring, on a
// 1024 by 1024 canvas. render.js draws every platform's images from it; the
// Android launcher layers (res/drawable/ic_launcher_*.xml), the web app's
// AnchorLogo (web/components/layout/anchor-logo.tsx) and the Flutter app's
// (lib/core/widgets/anchor_logo.dart) draw the same shapes themselves.

const themes = {
  light: { paper: ['#ffffff', '#e9eef4'], top: ['#f59a6c', '#ec7743'], lines: '#d5dbe4', anchor: '#2d3142', plus: '#ec7743' },
  dark: { paper: ['#30343f', '#1b1d23'], top: ['#ea8558', '#d66a3a'], lines: '#4a5164', anchor: '#f1f4f8', plus: '#ea8558' },
  // iOS tints a grey icon on black: the top and the + are the brightest.
  tinted: { paper: ['#000000', '#000000'], top: ['#e6e6e6', '#e6e6e6'], lines: '#505050', anchor: '#cccccc', plus: '#e6e6e6' },
};

const topHeight = 276;
const lines = 'M200,392H824A32,32 0 0 1 824,456H200A32,32 0 0 1 200,392Z'
  + 'M200,540H436A32,32 0 0 1 436,604H200A32,32 0 0 1 200,540Z'
  + 'M200,688H366A32,32 0 0 1 366,752H200A32,32 0 0 1 200,688Z';
const stroke = 49.4;
const anchor = 'M649.8,584.4A34.2,34.2 0 1 1 718.2,584.4A34.2,34.2 0 1 1 649.8,584.4Z'
  + 'M684,618.6V873.2M532,721.2A152,152 0 0 0 836,721.2M532,721.2H577.6M836,721.2H790.4';
// Right of the ring, above the right fluke, under the end of the top line.
const plus = 'M850,522V598M812,560H888';

/** CSS for the icon's colours; `auto` follows the system's dark mode. */
function style(theme) {
  const rules = (c) => `.s0{stop-color:${c.paper[0]}}.s1{stop-color:${c.paper[1]}}`
    + `.s2{stop-color:${c.top[0]}}.s3{stop-color:${c.top[1]}}`
    + `.lines{fill:${c.lines}}.anchor{stroke:${c.anchor}}.plus{stroke:${c.plus}}`;
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
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    + `<style>${style(theme)}</style>`
    + '<defs>'
    + '<linearGradient id="paper" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="1024"><stop offset="0" class="s0"/><stop offset="1" class="s1"/></linearGradient>'
    + `<linearGradient id="top" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="${topHeight}"><stop offset="0" class="s2"/><stop offset="1" class="s3"/></linearGradient>`
    + clip
    + '</defs>'
    + `<g${rounded ? ' clip-path="url(#outline)"' : ''}>`
    + '<path d="M0,0H1024V1024H0Z" fill="url(#paper)"/>'
    + `<path d="M0,0H1024V${topHeight}H0Z" fill="url(#top)"/>`
    + `<path d="${lines}" class="lines"/>`
    + `<g fill="none" stroke-width="${stroke}" stroke-linecap="round" stroke-linejoin="round">`
    + `<path d="${anchor}" class="anchor"/>`
    + `<path d="${plus}" class="plus"/>`
    + '</g></g></svg>';
}

module.exports = { icon, themes };
