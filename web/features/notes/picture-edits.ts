// Crop and mirror a picture in the text, as the Android app does: the new
// pixels are saved as a new attachment (see inline-image-tools.tsx).

/** A part of a picture, in shares (0 to 1) of its width and height. */
export interface CropArea {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

export type PictureEdit =
  | { crop: CropArea }
  | { mirror: "horizontally" | "vertically" };

export const WHOLE_PICTURE: CropArea = { left: 0, top: 0, right: 1, bottom: 1 };

/** The pixels a crop keeps: at least one, inside the picture. */
export function cropPixels(area: CropArea, width: number, height: number) {
  const clamp = (value: number) => Math.min(1, Math.max(0, value));
  const x = Math.round(clamp(Math.min(area.left, area.right)) * width);
  const y = Math.round(clamp(Math.min(area.top, area.bottom)) * height);
  const right = Math.round(clamp(Math.max(area.left, area.right)) * width);
  const bottom = Math.round(clamp(Math.max(area.top, area.bottom)) * height);
  return {
    x: Math.min(x, width - 1),
    y: Math.min(y, height - 1),
    width: Math.max(1, right - x),
    height: Math.max(1, bottom - y),
  };
}

/**
 * The picture with the edit applied, upright as it is shown. PNGs stay PNG
 * to keep their transparency; anything else becomes a JPEG, as on Android.
 */
export async function editPicture(
  picture: Blob,
  edit: PictureEdit,
): Promise<File> {
  // Applies the camera's rotation, so the edit is of what is seen.
  const bitmap = await createImageBitmap(picture);
  try {
    const source =
      "crop" in edit
        ? cropPixels(edit.crop, bitmap.width, bitmap.height)
        : { x: 0, y: 0, width: bitmap.width, height: bitmap.height };
    const canvas = document.createElement("canvas");
    canvas.width = source.width;
    canvas.height = source.height;
    const context = canvas.getContext("2d");
    if (!context) throw new Error("No canvas");
    if ("mirror" in edit) {
      const across = edit.mirror === "horizontally";
      context.translate(across ? source.width : 0, across ? 0 : source.height);
      context.scale(across ? -1 : 1, across ? 1 : -1);
    }
    context.drawImage(
      bitmap,
      source.x,
      source.y,
      source.width,
      source.height,
      0,
      0,
      source.width,
      source.height,
    );
    const type = picture.type === "image/png" ? "image/png" : "image/jpeg";
    const blob = await new Promise<Blob | null>((resolve) =>
      canvas.toBlob(resolve, type, 0.92),
    );
    if (!blob) throw new Error("Couldn’t encode the picture");
    return new File([blob], pictureName(type), { type });
  } finally {
    bitmap.close();
  }
}

/** “Picture 2026-10-28-14-03-12-345.jpg”, as Android names them. */
export function pictureName(type: string, at = new Date()) {
  const pad = (n: number, size = 2) => String(n).padStart(size, "0");
  const stamp = [
    at.getFullYear(),
    pad(at.getMonth() + 1),
    pad(at.getDate()),
    pad(at.getHours()),
    pad(at.getMinutes()),
    pad(at.getSeconds()),
    pad(at.getMilliseconds(), 3),
  ].join("-");
  return `Picture ${stamp}.${type === "image/png" ? "png" : "jpg"}`;
}
