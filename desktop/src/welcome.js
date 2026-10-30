// The moving parts of the welcome page, drawn as the Android app draws them
// (harbor_illustration.dart, anchor_plus_mark.dart): the harbor at the top,
// and the + of Anchor+ that hovers, glows, has sparks circling it and sends
// out a few of the things Anchor+ adds. With reduced motion both sit still.
(() => {
  const reducedMotion = matchMedia("(prefers-reduced-motion: reduce)");
  const darkScheme = matchMedia("(prefers-color-scheme: dark)");
  const TAU = 2 * Math.PI;

  // --- Colours ---------------------------------------------------------------

  const cssColor = (name) => getComputedStyle(document.documentElement).getPropertyValue(name).trim();

  function rgbOf(hex) {
    const n = Number.parseInt(hex.replace("#", "").slice(0, 6), 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }

  const rgba = ([r, g, b], a = 1) => `rgba(${Math.round(r)},${Math.round(g)},${Math.round(b)},${a})`;
  const lerp = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);

  const BRAND_ORANGE = rgbOf("#ef8354");
  const WHITE = [255, 255, 255];

  function harborPalette() {
    const page = rgbOf(cssColor("--page"));
    const base = {
      page,
      surface: rgbOf(cssColor("--surface")),
      border: rgbOf(cssColor("--border")),
      outline: rgbOf(cssColor("--text")),
      muted: rgbOf(cssColor("--muted")),
      roof: rgbOf(cssColor("--accent")),
    };
    if (darkScheme.matches) {
      return {
        ...base,
        skyTop: rgbOf("#2b3352"),
        skyMid: rgbOf("#22273a"),
        sun: rgbOf("#e9e4d6"),
        lamp: rgbOf("#ffcf8f"),
        beam: 0.5,
        sea1: lerp(page, rgbOf("#5c6f95"), 0.26),
        sea2: lerp(page, rgbOf("#5c6f95"), 0.14),
        sail: lerp(rgbOf("#e9e4d6"), page, 0.12),
        hasStars: true,
      };
    }
    return {
      ...base,
      skyTop: lerp(page, BRAND_ORANGE, 0.24),
      skyMid: lerp(page, BRAND_ORANGE, 0.07),
      sun: lerp(WHITE, BRAND_ORANGE, 0.62),
      lamp: rgbOf("#ffd8a6"),
      beam: 0.32,
      sea1: lerp(page, rgbOf("#6f86a8"), 0.22),
      sea2: lerp(page, rgbOf("#6f86a8"), 0.13),
      sail: base.surface,
      hasStars: false,
    };
  }

  /** Sizes a canvas to its box at the screen's pixel density. */
  function fit(canvas, width, height) {
    const ratio = window.devicePixelRatio || 1;
    canvas.style.height = `${height}px`;
    canvas.width = Math.round(width * ratio);
    canvas.height = Math.round(height * ratio);
    const ctx = canvas.getContext("2d");
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    return ctx;
  }

  // --- Harbor ------------------------------------------------------------------

  // Drawn on a 412 wide scene whose sea ends at y 252, scaled to the width.
  const SCENE_WIDTH = 412;
  const SCENE_BOTTOM = 252;
  const MAX_SCALE = 1.25;
  const STATIC_FRAME_TIME = 3;
  const LAMP = [335, 158.5];
  const SUN = [112, 168];
  const STARS = [
    [40, 70, 1.2],
    [92, 52, 1.0],
    [150, 86, 1.4],
    [196, 48, 1.0],
    [238, 92, 1.1],
    [276, 58, 1.3],
    [372, 74, 1.0],
    [24, 120, 0.9],
    [210, 128, 1.0],
  ];
  const GLINTS = [
    [212, 34],
    [217, 22],
    [222, 12],
  ];

  /** 0 to 1 and back over period seconds, easing at both ends. */
  const swing = (time, period) => (1 - Math.cos((TAU * time) / period)) / 2;
  const drift = (time, period, length) => (((time / period) % 1) * length);

  /** A wave along y repeating every length, closed off at edge. */
  function wave(y, rise, length, shift, left, right, edge) {
    const start = shift - length * (Math.floor((shift - left) / length) + 1);
    const path = new Path2D();
    path.moveTo(start, y);
    let x = start;
    for (let up = true; x < right; x += length / 2, up = !up) {
      path.quadraticCurveTo(x + length / 4, up ? y - rise : y + rise, x + length / 2, y);
    }
    path.lineTo(x, edge);
    path.lineTo(start, edge);
    path.closePath();
    return path;
  }

  function roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.roundRect(x, y, w, h, r);
  }

  function paintHarbor(ctx, width, height, time, c) {
    const scale = Math.min(width / SCENE_WIDTH, MAX_SCALE);
    const inset = (width - SCENE_WIDTH * scale) / 2 / scale;
    const left = -inset;
    const right = SCENE_WIDTH + inset;
    const top = SCENE_BOTTOM - height / scale;

    ctx.clearRect(0, 0, width, height);
    ctx.save();
    ctx.translate(inset * scale, height - SCENE_BOTTOM * scale);
    ctx.scale(scale, scale);
    ctx.clip(wave(246, 3, 140, -drift(time, 13, 140), left, right, top));

    const sky = ctx.createLinearGradient(0, 0, 0, 300);
    sky.addColorStop(0, rgba(c.skyTop));
    sky.addColorStop(0.55, rgba(c.skyMid));
    sky.addColorStop(1, rgba(c.page));
    ctx.fillStyle = sky;
    ctx.fillRect(left, top, right - left, 300 - top);

    if (c.hasStars) {
      STARS.forEach(([x, y, radius], i) => {
        const n = i + 1;
        const [period, lead] = n % 3 === 0 ? [11, 6] : n % 2 === 0 ? [9, 3] : [7, 0];
        ctx.fillStyle = rgba(c.outline, 0.55 - 0.4 * swing(time + lead, period));
        ctx.beginPath();
        ctx.arc(x, y, radius, 0, TAU);
        ctx.fill();
      });
    }

    const halo = 0.3 + 0.15 * swing(time, 8);
    const sunGlow = ctx.createRadialGradient(SUN[0], SUN[1], 0, SUN[0], SUN[1], 64);
    sunGlow.addColorStop(0, rgba(c.sun, halo));
    sunGlow.addColorStop(0.36, rgba(c.sun, halo));
    sunGlow.addColorStop(0.6, rgba(c.sun, halo * 0.35));
    sunGlow.addColorStop(1, rgba(c.sun, 0));
    ctx.fillStyle = sunGlow;
    ctx.beginPath();
    ctx.arc(SUN[0], SUN[1], 64, 0, TAU);
    ctx.fill();
    ctx.fillStyle = rgba(c.sun);
    ctx.beginPath();
    ctx.arc(SUN[0], SUN[1], 24, 0, TAU);
    ctx.fill();

    // The lighthouse beam sweeps slowly over the sea.
    ctx.save();
    ctx.translate(LAMP[0], LAMP[1]);
    ctx.rotate(((-7 + 16 * swing(time, 18)) * Math.PI) / 180);
    ctx.translate(-LAMP[0], -LAMP[1]);
    const beam = ctx.createLinearGradient(LAMP[0], LAMP[1], 145, 158.5);
    beam.addColorStop(0, rgba(c.lamp, 0.9 * c.beam));
    beam.addColorStop(1, rgba(c.lamp, 0));
    ctx.fillStyle = beam;
    ctx.beginPath();
    ctx.moveTo(LAMP[0], LAMP[1]);
    ctx.lineTo(152, 118.5);
    ctx.quadraticCurveTo(142, 152.5, 152, 198.5);
    ctx.closePath();
    ctx.fill();
    ctx.restore();

    ctx.fillStyle = rgba(c.sea1);
    ctx.fill(wave(206, 2.5, 120, -drift(time, 26, 120), left, right, 300));

    GLINTS.forEach(([y, w], i) => {
      ctx.fillStyle = rgba(c.sun, 0.15 + 0.4 * swing(time + 1.7 * i, 5));
      roundRect(ctx, SUN[0] - w / 2, y - 0.8, w, 1.6, 0.8);
      ctx.fill();
    });

    paintBoat(ctx, swing(time, 6), c);
    paintLighthouse(ctx, c);

    ctx.fillStyle = rgba(c.sea2);
    ctx.fill(wave(226, 3, 90, drift(time, 18, 90) - 90, left, right, 300));
    ctx.restore();
  }

  function paintBoat(ctx, rock, c) {
    const pivot = [220, 217.8];
    const outline = rgba(c.outline, 0.85);
    const mainsail = new Path2D("M223 175Q238 189 243 207L223 207Z");
    const jib = new Path2D("M221 179L217 206L200 207Z");
    ctx.save();
    ctx.translate(pivot[0], pivot[1] + 2.5 * rock);
    ctx.rotate(((-3 + 5.5 * rock) * Math.PI) / 180);
    ctx.translate(-pivot[0], -pivot[1]);
    ctx.fillStyle = rgba(c.sail);
    ctx.fill(mainsail);
    ctx.fill(jib);
    ctx.strokeStyle = rgba(c.border);
    ctx.lineWidth = 1;
    ctx.lineJoin = "round";
    ctx.stroke(mainsail);
    ctx.stroke(jib);
    ctx.strokeStyle = outline;
    ctx.lineCap = "round";
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(222, 210);
    ctx.lineTo(222, 171);
    ctx.stroke();
    ctx.lineWidth = 1.2;
    ctx.beginPath();
    ctx.moveTo(222, 208);
    ctx.lineTo(244, 208);
    ctx.stroke();
    ctx.fillStyle = rgba(BRAND_ORANGE);
    ctx.fill(new Path2D("M222 171L230 173.5L222 176Z"));
    ctx.fillStyle = outline;
    ctx.fill(new Path2D("M191 210L247 210L243.5 219.6Q242.6 222 240 222L205 222Q196 219.5 191 210Z"));
    ctx.restore();
  }

  function paintLighthouse(ctx, c) {
    const tower = new Path2D("M324 210L328 164L342 164L346 210Z");
    ctx.fillStyle = rgba(lerp(c.sea1, c.muted, 0.55));
    ctx.fill(new Path2D("M284 232Q294 202 316 204Q330 194 348 206Q368 212 376 232Z"));
    ctx.fillStyle = rgba(c.surface);
    ctx.fill(tower);
    ctx.strokeStyle = rgba(c.border);
    ctx.lineWidth = 1;
    ctx.stroke(tower);
    ctx.fillStyle = rgba(BRAND_ORANGE);
    ctx.fill(new Path2D("M326.3 184L343.7 184L344.6 194L325.4 194ZM327.6 170L342.4 170L343 176L327 176Z"));
    ctx.fillStyle = rgba(c.lamp);
    roundRect(ctx, 327, 153, 16, 11, 2);
    ctx.fill();
    ctx.fillStyle = rgba(c.roof);
    ctx.fill(new Path2D("M325 153L335 144L345 153Z"));
    ctx.strokeStyle = rgba(c.outline, 0.6);
    ctx.lineWidth = 1.6;
    ctx.lineCap = "butt";
    ctx.beginPath();
    ctx.moveTo(325, 164);
    ctx.lineTo(345, 164);
    ctx.stroke();
  }

  // --- The + of Anchor+ ----------------------------------------------------------

  const MARK_SIZE = 24;
  const HOVER_MS = 3200;
  // About twenty seconds of hovering, then it rests until clicked.
  const HOVER_CYCLES = 6;
  const BURST_MS = 1400;
  const FIRST_BURST_MS = 900;

  // What a click sends out: a few of the things Anchor+ adds (Lucide icons:
  // lock, snowflake, eye-off, scan-text, palette, grip-vertical, flame, images).
  const FEATURES = [
    "M5 11h14a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-7a2 2 0 0 1 2-2zM7 11V7a5 5 0 0 1 10 0v4",
    "M2 12h20M12 2v20M20 16l-4-4 4-4M4 8l4 4-4 4M16 4l-4 4-4-4M8 20l4-4 4 4",
    "M2 2l20 20M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68M6.61 6.61A13.53 13.53 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61M14.12 14.12a3 3 0 1 1-4.24-4.24",
    "M3 7V5a2 2 0 0 1 2-2h2M17 3h2a2 2 0 0 1 2 2v2M21 17v2a2 2 0 0 1-2 2h-2M7 21H5a2 2 0 0 1-2-2v-2M7 8h8M7 12h10M7 16h6",
    "M12 22a10 10 0 1 1 10-10c0 2.8-2.2 4-4 4h-2a2 2 0 0 0-1.5 3.3A1.7 1.7 0 0 1 12 22zM13.5 6.5h.01M17.5 10.5h.01M8.5 7.5h.01M6.5 12.5h.01",
    "M9 5h.01M9 12h.01M9 19h.01M15 5h.01M15 12h.01M15 19h.01",
    "M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z",
    "M18 22H4a2 2 0 0 1-2-2V6M10 2h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H10a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2zM22 13l-3.1-3.1a2 2 0 0 0-2.8 0L10 16M13 6h.01",
  ].map((d) => new Path2D(d));

  const easeOutCubic = (t) => 1 - (1 - t) ** 3;

  function paintPlus(ctx, box, phase, burst, accent, ink) {
    const side = MARK_SIZE;
    const lift = Math.sin(phase * TAU) * side * 0.09;
    const cx = box / 2;
    const cy = box / 2 + lift;
    const wavePos = (Math.sin(phase * TAU) + 1) / 2;
    ctx.clearRect(0, 0, box, box);

    // The glow under the cross breathes as it rises.
    const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, side * 0.95);
    glow.addColorStop(0, rgba(accent, 0.28 + 0.14 * wavePos));
    glow.addColorStop(1, rgba(accent, 0));
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(cx, cy, side * 0.95, 0, TAU);
    ctx.fill();

    // Three sparks on a tilted ring: the ones behind are drawn first,
    // smaller and fainter.
    const sparks = [];
    for (let i = 0; i < 3; i++) {
      const a = (phase / 2 + i / 3) * TAU;
      const depth = Math.sin(a);
      const rx = Math.cos(a) * side * 0.95;
      const ry = depth * side * 0.32;
      sparks.push({
        depth,
        x: cx + rx * Math.cos(-0.5) - ry * Math.sin(-0.5),
        y: cy + rx * Math.sin(-0.5) + ry * Math.cos(-0.5),
      });
    }
    sparks.sort((a, b) => a.depth - b.depth);
    const spark = (s) => {
      const near = (s.depth + 1) / 2;
      ctx.fillStyle = rgba(ink, 0.35 + 0.65 * near);
      ctx.beginPath();
      ctx.arc(s.x, s.y, side * (0.05 + 0.05 * near), 0, TAU);
      ctx.fill();
    };
    sparks.filter((s) => s.depth < 0).forEach(spark);

    // The cross: rounded bars with a light running across them.
    const bar = side * 0.24;
    const arm = side * 0.5;
    const sweep = phase * 3 - 1;
    const clamp = (v) => Math.min(1, Math.max(0, v));
    const shine = ctx.createLinearGradient(cx - arm, cy - arm, cx + arm, cy + arm);
    shine.addColorStop(0, rgba(ink));
    shine.addColorStop(clamp(sweep - 0.25), rgba(accent));
    shine.addColorStop(clamp(sweep), rgba(WHITE));
    shine.addColorStop(clamp(sweep + 0.25), rgba(accent));
    shine.addColorStop(1, rgba(ink));
    ctx.fillStyle = shine;
    ctx.beginPath();
    ctx.roundRect(cx - arm, cy - bar / 2, arm * 2, bar, bar / 2);
    ctx.roundRect(cx - bar / 2, cy - arm, bar, arm * 2, bar / 2);
    ctx.fill();

    sparks.filter((s) => s.depth >= 0).forEach(spark);

    // The features fly out from the cross and fade on the way.
    if (burst !== null) {
      const progress = easeOutCubic(burst);
      const reach = side * 2.2 * progress;
      const iconSize = side * 0.7;
      const opacity = clamp((1 - burst) * Math.min(1, burst * 6));
      const iconScale = (0.4 + 0.6 * progress) * (iconSize / 24);
      FEATURES.forEach((icon, i) => {
        const angle = -Math.PI / 2 + (i * TAU) / FEATURES.length;
        ctx.save();
        ctx.globalAlpha = opacity;
        ctx.translate(box / 2 + Math.cos(angle) * reach, box / 2 + Math.sin(angle) * reach);
        ctx.scale(iconScale, iconScale);
        ctx.translate(-12, -12);
        ctx.strokeStyle = rgba(ink);
        ctx.lineWidth = 2;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.stroke(icon);
        ctx.restore();
      });
    }
  }

  // --- Running them --------------------------------------------------------------

  const harbor = document.getElementById("harbor");
  const plus = document.getElementById("plus");
  let harborCtx = null;
  let harborSize = [0, 0];
  let plusCtx = null;
  let plusBox = 0;
  let palette = null;
  let markColors = null;

  function layout() {
    const width = harbor.clientWidth;
    const height = SCENE_BOTTOM * Math.min(width / SCENE_WIDTH, MAX_SCALE);
    harborCtx = fit(harbor, width, height);
    harborSize = [width, height];
    plusBox = plus.clientWidth;
    plusCtx = fit(plus, plusBox, plusBox);
    palette = harborPalette();
    markColors = [rgbOf(cssColor("--accent")), rgbOf(cssColor("--accent-ink"))];
  }

  const started = performance.now();
  let hoverFrom = started;
  let burstFrom = null;
  let firstBurst = null;
  let frame = 0;

  function draw(now) {
    frame = 0;
    const still = reducedMotion.matches;
    const seconds = still ? STATIC_FRAME_TIME : (now - started) / 1000;
    paintHarbor(harborCtx, harborSize[0], harborSize[1], seconds, palette);

    const hoverElapsed = now - hoverFrom;
    const hovering = !still && hoverElapsed < HOVER_MS * HOVER_CYCLES;
    const phase = hovering ? (hoverElapsed % HOVER_MS) / HOVER_MS : 0;
    let burst = null;
    if (!still && burstFrom !== null) {
      burst = (now - burstFrom) / BURST_MS;
      if (burst >= 1) {
        burst = null;
        burstFrom = null;
      }
    }
    paintPlus(plusCtx, plusBox, phase, burst, ...markColors);

    // The harbor keeps moving; with reduced motion one frame is enough.
    if (!still) frame = requestAnimationFrame(draw);
  }

  function redraw() {
    if (!frame) frame = requestAnimationFrame(draw);
  }

  function celebrate() {
    if (reducedMotion.matches) return;
    burstFrom = performance.now();
    if (burstFrom - hoverFrom >= HOVER_MS * HOVER_CYCLES) hoverFrom = burstFrom;
    redraw();
  }

  function restart() {
    layout();
    clearTimeout(firstBurst);
    if (!reducedMotion.matches && burstFrom === null && firstBurst === null) {
      // Shows once what the + stands for, after the page has settled.
      firstBurst = setTimeout(celebrate, FIRST_BURST_MS);
    }
    redraw();
  }

  plus.parentElement.addEventListener("click", celebrate);
  window.addEventListener("resize", () => {
    layout();
    redraw();
  });
  darkScheme.addEventListener("change", restart);
  reducedMotion.addEventListener("change", restart);
  // Draw once the fonts have set the title, so the + sits after it.
  document.fonts.ready.then(restart);
})();
