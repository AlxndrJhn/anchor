// The feature demos of the demo build: each opens at /<slug> (on GitHub
// Pages, /anchor/demo/<slug>), loads its own notes and plays its steps.

import type { Step } from "./runner";
import type { Seed } from "./seed";

export interface Demo {
  slug: string;
  title: string;
  /** One line for the list in Settings. */
  summary: string;
  seed: Seed;
  /** The page it opens on. */
  start: string;
  steps: Step[];
  /** Shown when it has played: what to try now. */
  outro: string;
}

const T = {
  work: { id: "tag-work", name: "Work", color: "#64B5F6" },
  home: { id: "tag-home", name: "Home", color: "#81C784" },
  ideas: { id: "tag-ideas", name: "Ideas", color: "#FFB74D" },
  travel: { id: "tag-travel", name: "Travel", color: "#BA68C8" },
};

const allTags = Object.values(T);

/** Notes most demos start with. */
const everyday: Seed["notes"] = [
  {
    id: "n-groceries",
    title: "Groceries",
    background: "color_yellow",
    tags: ["Home"],
    lines: [
      { item: "Oat milk" },
      { item: "Tomatoes", done: true },
      { item: "Basil" },
      { item: "Sourdough bread" },
    ],
  },
  {
    id: "n-standup",
    title: "Stand-up notes",
    tags: ["Work"],
    lines: [
      "Release on Friday, after the QA pass.",
      "Ask Sam about the new onboarding screens.",
    ],
  },
  {
    id: "n-trip",
    title: "Lisbon trip",
    background: "color_blue",
    tags: ["Travel"],
    lines: ["Tram 28 early in the morning", "Pastéis de Belém", "LX Factory"],
  },
  {
    id: "n-ideas",
    title: "App ideas",
    tags: ["Ideas"],
    lines: ["A plant watering reminder", "Recipe cards from photos"],
  },
  {
    id: "n-books",
    title: "Books to read",
    background: "color_green",
    lines: [
      { item: "The Overstory" },
      { item: "Piranesi", done: true },
      { item: "Project Hail Mary" },
    ],
  },
];

export const welcome: Seed = {
  tags: allTags,
  notes: [
    {
      id: "n-welcome",
      title: "Welcome to the Anchor demo",
      pinned: true,
      background: "color_teal",
      lines: [
        "Everything here lives only in this tab: a reload starts over.",
        "Settings › Feature demos plays a short demo of each feature.",
      ],
    },
    ...everyday,
  ],
};

/** Opens a note's “More” menu in the editor and picks an item. */
const fromMoreMenu = (item: string, say?: string): Step[] => [
  { click: "More", say },
  { click: { css: "[role=menuitem]", text: item } },
];

/** Opens a note from the notes list by its title. */
const openNote = (title: string, say?: string): Step => ({
  click: { css: `a.nc-link[aria-label="${title}"]` },
  say,
});

export const demos: Demo[] = [
  {
    slug: "freeze",
    title: "Freeze a note",
    summary:
      "Nobody can change, trash or delete it until its owner unfreezes it.",
    seed: { tags: allTags, notes: everyday },
    start: "/notes",
    steps: [
      openNote("Stand-up notes", "Open a note you want to keep as it is."),
      ...fromMoreMenu("Freeze", "In the More menu, choose Freeze."),
      {
        say: "Frozen: the text can't be edited, and the note can't be trashed or deleted.",
      },
      { wait: 1500 },
      ...fromMoreMenu("Unfreeze", "Unfreeze it from the same menu."),
      { say: "Now it can be edited again." },
    ],
    outro:
      "Try it: freeze a note, then try to type in it or move it to the trash.",
  },
  {
    slug: "invisible",
    title: "Invisible notes",
    summary:
      "An invisible note stays out of your lists; only a search finds it.",
    seed: { tags: allTags, notes: everyday },
    start: "/notes",
    steps: [
      openNote("App ideas", "Open a note to tuck away."),
      ...fromMoreMenu("Make invisible", "More › Make invisible."),
      { click: "Back", say: "Back in the list, the note is gone…" },
      { wait: 1200 },
      {
        type: "plant",
        into: { css: 'input[aria-label="Search notes"]' },
        say: "…but a search still finds it.",
      },
      { wait: 1500 },
      { say: "The Invisible filter lists all of them." },
    ],
    outro:
      "Try it: make a note invisible, then find it with a search or Filter › Invisible.",
  },
  {
    slug: "copy",
    title: "Make a copy",
    summary: "Copy a note, with its pictures and attachments.",
    seed: { tags: allTags, notes: everyday },
    start: "/notes",
    steps: [
      openNote("Groceries", "Open a note."),
      ...fromMoreMenu("Make a copy", "More › Make a copy."),
      { wait: 1200 },
      { click: "Back", say: "The copy sits next to the original." },
      { wait: 1500 },
    ],
    outro: "Try it: copy a note, then change the copy.",
  },
];

export function demoBySlug(slug: string): Demo | undefined {
  return demos.find((demo) => demo.slug === slug);
}
