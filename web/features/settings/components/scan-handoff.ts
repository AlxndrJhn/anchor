import { prefersReducedMotion } from "@/lib/motion";

/** About how long the QR code takes from the dialog to the phone's row; it
 * lands when the row's teleport bursts, once that has started. */
const FLIGHT_MS = 1500;
// The "scanned" pulse before it takes off.
const PULSE_MS = 260;
// The share of the flight the QR code takes to become an anchor.
const MORPH_SHARE = 0.35;
// Whole turns, so it lands upright.
const SPIN_TURNS = 2;
// The teleport's burst into its +, 650ms in, as motion.css sets it.
const TELEPORT_IMPACT_MS = 650;
/** How long a scanned phone's teleport waits, so it bursts as the anchor
 * lands. */
export const TELEPORT_WAIT_MS = FLIGHT_MS - TELEPORT_IMPACT_MS;
const TRAIL_EVERY_MS = 40;
// The anchor's size as it reaches the device icon.
const LANDING_SIZE = 22;
// The anchor takes this share of the QR code's box.
const ANCHOR_SHARE = 0.7;

// The anchor of the app icon (anchor-logo.tsx), in its own units.
const ANCHOR_SVG = `<svg class="qr-anchor" viewBox="-4 2 108 100" fill="none" stroke="currentColor" stroke-width="13" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="50" cy="18" r="9"/><path d="M50 27V94M10 54A40 40 0 0 0 90 54M10 54H22M90 54H78"/></svg>`;

let onScan: ((sessionId: string) => void) | null = null;

/** While the QR code shows, the next device to sign in is the phone that
 * scanned it. Returns a function that stops waiting. */
export function waitForScan(handler: (sessionId: string) => void) {
  onScan = handler;
  return () => {
    if (onScan === handler) onScan = null;
  };
}

/** Hands a device that just turned up to the QR code waiting for it, if one
 * is; true when it was. */
export function handOffScan(sessionId: string) {
  const handler = onScan;
  if (!handler) return false;
  onScan = null;
  handler(sessionId);
  return true;
}

const easeInOutSine = (t: number) => (1 - Math.cos(Math.PI * t)) / 2;
const smoothstep = (t: number) => t * t * (3 - 2 * t);
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

/**
 * Lifts the QR code out of its dialog, turns it into the anchor of Anchor+
 * and spins that, shrinking, to the icon of the phone that scanned the code
 * in the Devices list, where it lands as the teleport bursts into the +.
 * Follows the
 * icon as the page scrolls to it. Does nothing with reduced motion.
 */
export function flyQrTo(qr: Element, sessionId: string) {
  if (prefersReducedMotion()) return;
  const from = qr.getBoundingClientRect();
  if (!from.width) return;
  const ghost = document.createElement("div");
  ghost.className = "qr-flight";
  const card = document.createElement("div");
  card.className = "qr-card";
  card.append(qr.cloneNode(true));
  ghost.append(card);
  ghost.insertAdjacentHTML("beforeend", ANCHOR_SVG);
  Object.assign(ghost.style, {
    left: `${from.left}px`,
    top: `${from.top}px`,
    width: `${from.width}px`,
    height: `${from.height}px`,
  });
  document.body.append(ghost);
  // The dialog closes around it; only the flying copy shows.
  if (qr instanceof SVGElement || qr instanceof HTMLElement)
    qr.style.visibility = "hidden";

  const ax = from.left + from.width / 2;
  const ay = from.top + from.height / 2;
  const start = performance.now();
  const landingScale = LANDING_SIZE / (from.width * ANCHOR_SHARE);
  let target: Element | null = null;
  let landAt = start + FLIGHT_MS;
  let isTimed = false;
  let lastTrail = start;

  const step = (now: number) => {
    // Brings the row into view once the dialog, which holds the page still,
    // has gone.
    if (!target && !document.querySelector('[data-slot="dialog"]')) {
      target = document.querySelector(
        `[data-arrival="${CSS.escape(sessionId)}"] .teleport-icon`,
      );
      target
        ?.closest("[data-arrival]")
        ?.scrollIntoView({ block: "center", behavior: "smooth" });
    }
    // Lands as the teleport bursts into its +, by the teleport's own clock,
    // which may run late on a busy page.
    if (target && !isTimed) {
      const land = target
        .closest("[data-arrival]")
        ?.querySelector(".teleport-plus")
        ?.getAnimations()
        .find(
          (a) =>
            a instanceof CSSAnimation && a.animationName === "teleport-plus",
        );
      const delay = Number(land?.effect?.getTiming().delay ?? 0);
      if (land?.startTime != null) {
        landAt = Math.max(start + PULSE_MS * 2, Number(land.startTime) + delay);
        isTimed = true;
      }
    }
    if (now >= landAt) {
      ghost.remove();
      return;
    }
    const end = target?.getBoundingClientRect();
    const bx = end ? end.left + end.width / 2 : ax;
    const by = end ? end.top + end.height / 2 : ay;

    const pulse = Math.min(1, (now - start) / PULSE_MS);
    const t = Math.max(
      0,
      (now - start - PULSE_MS) / (landAt - start - PULSE_MS),
    );
    const e = easeInOutSine(t);
    const morph = smoothstep(Math.min(1, t / MORPH_SHARE));
    // A curve that rises before it drops onto the icon.
    const cx = lerp(ax, bx, 0.35);
    const cy = Math.min(ay, by) - Math.max(120, Math.abs(by - ay) * 0.3);
    const x = (1 - e) ** 2 * ax + 2 * (1 - e) * e * cx + e ** 2 * bx;
    const y = (1 - e) ** 2 * ay + 2 * (1 - e) * e * cy + e ** 2 * by;
    const scale =
      lerp(1, landingScale, e) * (1 + 0.06 * Math.sin(Math.PI * pulse));

    ghost.style.transform = `translate(${x - ax}px, ${y - ay}px) rotate(${-8 * pulse * (1 - morph) + 360 * SPIN_TURNS * e}deg) scale(${scale})`;
    ghost.style.opacity = String(t < 0.92 ? 1 : 1 - (t - 0.92) / 0.08);
    ghost.style.setProperty("--qr-morph", String(morph));
    ghost.style.setProperty("--qr-ring", `${Math.sin(Math.PI * pulse) * 10}px`);
    // The glow stays about the same on screen as the anchor shrinks.
    ghost.style.setProperty("--qr-glow", `${(4 + 6 * e) / scale}px`);

    if (morph > 0.5 && now - lastTrail >= TRAIL_EVERY_MS) {
      lastTrail = now;
      const spark = document.createElement("span");
      spark.className = "qr-trail";
      const size = Math.max(4, Math.min(14, from.width * scale * 0.2));
      Object.assign(spark.style, {
        left: `${x - size / 2}px`,
        top: `${y - size / 2}px`,
        width: `${size}px`,
        height: `${size}px`,
      });
      spark.addEventListener("animationend", () => spark.remove());
      document.body.append(spark);
    }
    requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}
