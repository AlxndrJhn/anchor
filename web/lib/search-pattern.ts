/**
 * Each letter and the accented letters a search counts as the same, so
 * "apfel" finds "Äpfel" and "cafe" finds "café". Built on first use.
 */
let accented: Map<string, string> | null = null;
let letterOf: Map<string, string> | null = null;

function tables() {
  if (accented && letterOf) return { accented, letterOf };
  const variants = new Map<string, string>();
  const base = new Map<string, string>();
  const add = (letter: string, variant: string) => {
    variants.set(letter, (variants.get(letter) ?? "") + variant);
    base.set(variant, letter);
  };
  for (const [from, to] of [
    [0xc0, 0x24f],
    [0x1e00, 0x1eff],
  ]) {
    for (let code = from; code <= to; code++) {
      const char = String.fromCodePoint(code);
      const letter = char.normalize("NFD").replace(/\p{M}/gu, "");
      if (letter !== char && /^[A-Za-z]$/.test(letter)) add(letter, char);
    }
  }
  // Letters with a stroke have no accent to take off.
  for (const [letter, variant] of [
    ["o", "ø"],
    ["O", "Ø"],
    ["d", "đ"],
    ["D", "Đ"],
    ["l", "ł"],
    ["L", "Ł"],
    ["h", "ħ"],
    ["H", "Ħ"],
    ["i", "ı"],
  ]) {
    add(letter, variant);
  }
  accented = variants;
  letterOf = base;
  return { accented, letterOf };
}

const patterns = new Map<string, RegExp>();

/**
 * A pattern for [term] as plain text in any case, where every letter also
 * matches its accented forms (typed accented or not) and "ss" matches "ß".
 * Global, for finding every match; reset `lastIndex` before reusing it.
 */
export function searchPattern(term: string): RegExp {
  let pattern = patterns.get(term);
  if (pattern) return pattern;
  const { accented, letterOf } = tables();
  const letters = Array.from(term, (char) => letterOf.get(char) ?? char);
  let source = "";
  for (let i = 0; i < letters.length; i++) {
    const letter = letters[i];
    const pair = (letter + (letters[i + 1] ?? "")).toLowerCase();
    if (pair === "ss" || letter === "ß" || letter === "ẞ") {
      source += "(?:ss|ß|ẞ)";
      if (pair === "ss") i++;
      continue;
    }
    const variants = accented.get(letter);
    source += variants
      ? `[${letter}${variants}]`
      : letter.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }
  pattern = new RegExp(source, "gi");
  if (patterns.size > 50) patterns.clear();
  patterns.set(term, pattern);
  return pattern;
}

/** Whether [text] has [term], ignoring case and accents. */
export function hasSearchTerm(text: string, term: string) {
  const pattern = searchPattern(term);
  pattern.lastIndex = 0;
  return pattern.test(text);
}
