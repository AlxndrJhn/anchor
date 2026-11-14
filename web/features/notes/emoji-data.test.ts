import { describe, expect, it } from "vitest";
import {
  addRecent,
  type Emoji,
  groupEmojis,
  loadEmojis,
  searchEmojis,
} from "./emoji-data";

const emoji = (
  label: string,
  unicode: string,
  group: number,
  tags: string[] = [],
  order = 0,
): Emoji => ({
  hexcode: unicode,
  label,
  unicode,
  group,
  order,
  tags,
});

const smile = emoji("grinning face", "😀", 0, ["face", "grin"], 1);
const wave = emoji("waving hand", "👋", 1, ["hello", "hi", "wave"], 2);
const cat = emoji("cat", "🐈", 3, ["pet"], 3);
const catFace = emoji("cat face", "🐱", 3, ["pet", "face"], 4);
const pizza = emoji("pizza", "🍕", 4, ["cheese", "slice"], 5);

describe("emoji data", () => {
  it("groups smileys and people together, as WhatsApp does", () => {
    const sections = groupEmojis([pizza, cat, wave, smile]);
    expect(sections.map((s) => s.id)).toEqual([
      "people",
      "nature",
      "food",
      "activity",
      "travel",
      "objects",
      "symbols",
      "flags",
    ]);
    expect(sections[0].emojis).toEqual([smile, wave]);
    expect(sections[1].emojis).toEqual([cat]);
  });

  it("finds emojis by name first, then by tag", () => {
    const all = [smile, wave, cat, catFace, pizza];
    expect(searchEmojis(all, "cat")).toEqual([cat, catFace]);
    expect(searchEmojis(all, "face")).toEqual([smile, catFace]);
    expect(searchEmojis(all, "pet")).toEqual([cat, catFace]);
    expect(searchEmojis(all, "hello")).toEqual([wave]);
    expect(searchEmojis(all, "cat face")).toEqual([catFace]);
    expect(searchEmojis(all, "zebra")).toEqual([]);
    expect(searchEmojis(all, "  ")).toEqual([]);
  });

  it("keeps the last used first, once each, up to a limit", () => {
    expect(addRecent(["🍕", "😀"], "😀")).toEqual(["😀", "🍕"]);
    expect(addRecent(["a", "b", "c"], "d", 3)).toEqual(["d", "a", "b"]);
  });

  it("loads every emoji in the app's categories, with skin tones", async () => {
    const all = await loadEmojis();
    expect(all.length).toBeGreaterThan(1800);
    const sections = groupEmojis(all);
    expect(sections.every((s) => s.emojis.length > 0)).toBe(true);
    expect(all.some((e) => e.group === 2)).toBe(false);
    expect(searchEmojis(all, "pizza")[0].unicode).toBe("🍕");
    expect(all.find((e) => e.label === "waving hand")?.skins).toHaveLength(5);
  });
});
