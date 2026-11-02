import { type CropArea, WHOLE_PICTURE } from "./picture-edits";

/**
 * A live picture placed in the text: a camera or a screen of the device that
 * added it, shown live to every device that opens the note. A Delta embed,
 * `{"live-image": "{\"id\":…,\"source\":\"camera\",\"device\":…}"}`, like a
 * picture's; its width is a share of the text's width and its crop a part
 * of the video, so neither changes what the device sends.
 */
export const LIVE_IMAGE_EMBED = "live-image";

export type LiveSource = "camera" | "screen";

export interface LiveImage {
  id: string;
  source: LiveSource;
  /** The device that shows its camera or screen (see live-hub.ts). */
  device: string;
  /** That device's name, to say whose video is awaited. */
  label?: string;
  /** Which of that device's cameras. */
  camera?: string;
  /** 0 to 1; missing for the full width. */
  width?: number;
  /** Missing for the whole video. */
  crop?: CropArea;
}

const isShare = (value: unknown): value is number =>
  typeof value === "number" && value >= 0 && value <= 1;

const text = (value: unknown, max = 200) =>
  typeof value === "string" && value.trim()
    ? value.trim().slice(0, max)
    : undefined;

function parseCrop(value: unknown): CropArea | undefined {
  if (!value || typeof value !== "object") return undefined;
  const { left, top, right, bottom } = value as Partial<CropArea>;
  if (![left, top, right, bottom].every(isShare)) return undefined;
  const area = {
    left: Math.min(left!, right!),
    top: Math.min(top!, bottom!),
    right: Math.max(left!, right!),
    bottom: Math.max(top!, bottom!),
  };
  if (area.right - area.left < 0.01 || area.bottom - area.top < 0.01)
    return undefined;
  return isWhole(area) ? undefined : area;
}

const isWhole = (area: CropArea) =>
  area.left <= 0.001 &&
  area.top <= 0.001 &&
  area.right >= 0.999 &&
  area.bottom >= 0.999;

export function parseLiveImage(value: unknown): LiveImage | null {
  if (typeof value !== "string") return null;
  try {
    const data = JSON.parse(value) as Record<string, unknown> | null;
    if (!data || typeof data.id !== "string" || !data.id) return null;
    const device = text(data.device, 64);
    if (!device) return null;
    return {
      id: data.id,
      source: data.source === "screen" ? "screen" : "camera",
      device,
      label: text(data.label, 80),
      camera: text(data.camera),
      width:
        typeof data.width === "number" && data.width > 0 && data.width < 1
          ? data.width
          : undefined,
      crop: parseCrop(data.crop),
    };
  } catch {
    return null;
  }
}

const round = (value: number) => Number(value.toFixed(3));

export function encodeLiveImage(image: LiveImage): string {
  const crop = image.crop && parseCrop(image.crop);
  return JSON.stringify({
    id: image.id,
    source: image.source,
    device: image.device,
    ...(image.label ? { label: image.label } : {}),
    ...(image.camera ? { camera: image.camera } : {}),
    ...(image.width !== undefined && image.width < 1
      ? { width: round(image.width) }
      : {}),
    ...(crop
      ? {
          crop: {
            left: round(crop.left),
            top: round(crop.top),
            right: round(crop.right),
            bottom: round(crop.bottom),
          },
        }
      : {}),
  });
}

/** The live images a note's stored content shows. */
export function liveImagesIn(content: string | null | undefined): LiveImage[] {
  if (!content) return [];
  let ops: unknown;
  try {
    ops = (JSON.parse(content) as { ops?: unknown })?.ops;
  } catch {
    return [];
  }
  if (!Array.isArray(ops)) return [];
  const images: LiveImage[] = [];
  for (const op of ops) {
    const insert = (op as { insert?: unknown })?.insert;
    if (!insert || typeof insert !== "object") continue;
    const image = parseLiveImage(
      (insert as Record<string, unknown>)[LIVE_IMAGE_EMBED],
    );
    if (image) images.push(image);
  }
  return images;
}

/**
 * How a cropped video sits in its frame: the frame keeps the crop's shape and
 * the video, larger than it, is moved so only the crop shows. Percentages of
 * the frame; `aspect` is the frame's width over its height.
 */
export function cropLayout(
  crop: CropArea | undefined,
  videoWidth: number,
  videoHeight: number,
) {
  const area = crop ?? WHOLE_PICTURE;
  const across = area.right - area.left;
  const down = area.bottom - area.top;
  const aspect =
    videoWidth > 0 && videoHeight > 0
      ? (across * videoWidth) / (down * videoHeight)
      : 16 / 9;
  return {
    aspect,
    width: 100 / across,
    height: 100 / down,
    left: (-area.left / across) * 100,
    top: (-area.top / down) * 100,
  };
}
