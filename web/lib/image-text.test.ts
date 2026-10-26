import { describe, expect, it } from "vitest";
import {
  type ImageWord,
  imageWordAt,
  imageWordsIn,
  joinImageWords,
  type TesseractBlock,
  wordsFromBlocks,
} from "./image-text";

const word = (
  text: string,
  left: number,
  top: number,
  line = 0,
  block = 0,
): ImageWord => ({
  text,
  left,
  top,
  right: left + 100,
  bottom: top + 20,
  line,
  block,
});

const box = (x0: number, y0: number) => ({
  x0,
  y0,
  x1: x0 + 100,
  y1: y0 + 20,
});

describe("wordsFromBlocks", () => {
  it("lists the words in reading order, a paragraph per block", () => {
    const blocks: TesseractBlock[] = [
      {
        paragraphs: [
          {
            lines: [
              {
                words: [
                  { text: "Shopping", bbox: box(0, 0) },
                  { text: "list", bbox: box(110, 0) },
                ],
              },
            ],
          },
          {
            lines: [
              { words: [{ text: "Milk", bbox: box(0, 60) }] },
              { words: [{ text: " ", bbox: box(0, 90) }] },
              { words: [{ text: "Call ", bbox: box(0, 120) }] },
            ],
          },
        ],
      },
    ];

    const words = wordsFromBlocks(blocks);

    expect(words.map((w) => [w.text, w.line, w.block])).toEqual([
      ["Shopping", 0, 0],
      ["list", 0, 0],
      ["Milk", 1, 1],
      ["Call", 2, 1],
    ]);
    expect(words[1]).toMatchObject({ left: 110, top: 0, right: 210 });
    expect(joinImageWords(words)).toBe("Shopping list\n\nMilk\nCall");
  });
});

describe("joinImageWords", () => {
  it("keeps the lines and paragraphs of a selection", () => {
    const words = [
      word("Milk", 0, 0),
      word("and", 110, 0),
      word("bread", 0, 30, 1),
      word("Call", 0, 90, 2, 1),
    ];

    expect(joinImageWords(words)).toBe("Milk and\nbread\n\nCall");
    expect(joinImageWords(words.slice(1, 3))).toBe("and\nbread");
    expect(joinImageWords(words, { paragraphs: false })).toBe(
      "Milk and\nbread\nCall",
    );
  });
});

describe("imageWordAt", () => {
  const words = [
    word("Milk", 0, 0),
    word("bread", 140, 0),
    word("Call", 0, 60, 1),
  ];

  it("finds the word it touches", () => {
    expect(imageWordAt(words, 50, 10)).toBe(0);
    expect(imageWordAt(words, 150, 15)).toBe(1);
    expect(imageWordAt(words, 10, 70)).toBe(2);
  });

  it("finds the nearest word on the line just beside it", () => {
    expect(imageWordAt(words, 115, 10)).toBe(0);
    expect(imageWordAt(words, 130, 10)).toBe(1);
    expect(imageWordAt(words, 50, 28)).toBe(0);
  });

  it("finds none far from any text", () => {
    expect(imageWordAt(words, 50, 45)).toBeNull();
    expect(imageWordAt(words, 400, 10)).toBeNull();
  });
});

describe("imageWordsIn", () => {
  const words = [
    word("Milk", 0, 0),
    word("bread", 140, 0),
    word("Call", 0, 60, 1),
  ];
  const box = (left: number, top: number, right: number, bottom: number) => ({
    left,
    top,
    right,
    bottom,
  });

  it("takes the words a box touches, in reading order", () => {
    expect(imageWordsIn(words, box(50, 10, 60, 70))).toEqual([0, 2]);
    expect(imageWordsIn(words, box(90, -5, 150, 5))).toEqual([0, 1]);
    expect(imageWordsIn(words, box(110, 30, 130, 50))).toEqual([]);
  });
});
