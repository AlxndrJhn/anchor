/**
 * "Grab image text": reads the English text in a picture in the browser with
 * Tesseract. Its code and language data load from a CDN the first time, so
 * this needs a connection.
 */
export async function readImageText(image: Blob | string): Promise<string> {
  const { createWorker } = await import("tesseract.js");
  const worker = await createWorker("eng");
  try {
    const { data } = await worker.recognize(image);
    return data.text
      .split("\n")
      .map((line) => line.trimEnd())
      .join("\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  } finally {
    await worker.terminate();
  }
}
