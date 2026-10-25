import { parseStoredContent } from "./quill";
import { deltaToLines, getLineText, indentOf } from "./quill-lines";

/**
 * A note as plain text for other apps, as Google Keep sends it: the title,
 * a blank line, then the text with ☐/☑ for checklist items and • for
 * bullets, indented with two spaces per level.
 */
export function noteToPlainText(title: string, content: string | null) {
  const body = deltaToLines(parseStoredContent(content).ops ?? [])
    .map((line, index, lines) => {
      const text = getLineText(line);
      const list = line.newlineOp.attributes?.list;
      const pad = "  ".repeat(indentOf(line));
      if (list === "checked") return `${pad}☑ ${text}`;
      if (list === "unchecked") return `${pad}☐ ${text}`;
      if (list === "bullet") return `${pad}• ${text}`;
      if (list === "ordered") {
        let number = 1;
        for (let i = index - 1; i >= 0; i--) {
          if (lines[i].newlineOp.attributes?.list !== "ordered") break;
          if (indentOf(lines[i]) === indentOf(line)) number++;
        }
        return `${pad}${number}. ${text}`;
      }
      return text;
    })
    .join("\n")
    .trim();
  const heading = title.trim();
  return [heading, body].filter(Boolean).join("\n\n");
}

/**
 * Hands the note to the system's share sheet where there is one (phones,
 * Safari, Edge), otherwise copies it. Returns what happened.
 */
export async function sendNote(
  title: string,
  content: string | null,
): Promise<"shared" | "copied" | "cancelled"> {
  const text = noteToPlainText(title, content);
  if (typeof navigator.share === "function") {
    try {
      await navigator.share({ title: title.trim() || undefined, text });
      return "shared";
    } catch (error) {
      if ((error as DOMException)?.name === "AbortError") return "cancelled";
    }
  }
  await navigator.clipboard.writeText(text);
  return "copied";
}
