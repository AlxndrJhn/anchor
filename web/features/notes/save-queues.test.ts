import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { NoteDraft, SaveOutcome } from "./save-queue";
import type { Note } from "./types";

const saveNote = vi.fn<(id: string, data: unknown) => Promise<SaveOutcome>>();
const createNote = vi.fn<(data: { id: string }) => Promise<Note>>();
vi.mock("./api", () => ({
  saveNote: (id: string, data: unknown) => saveNote(id, data),
  createNote: (data: { id: string }) => createNote(data),
  isRetryableError: () => true,
}));
vi.mock("@/components/ui/toast", () => ({
  toast: { error: vi.fn(), info: vi.fn() },
}));

const store = new Map<string, string>();
const localStorage = {
  getItem: (key: string) => store.get(key) ?? null,
  setItem: (key: string, value: string) => store.set(key, value),
  removeItem: (key: string) => store.delete(key),
};
vi.stubGlobal("localStorage", localStorage);
vi.stubGlobal("window", {
  localStorage,
  setTimeout,
  clearTimeout,
  addEventListener: () => {},
});

const { useAuthStore } = await import("@/features/auth/store");
const { readOutbox, writeOutboxEntry } = await import("./outbox");
const { allSaved, noteSaveQueue, restoreOutbox, retryAllSaves } = await import(
  "./save-queues"
);
const { useSyncStatus } = await import("@/features/sync/status");
const { QueryClient } = await import("@tanstack/react-query");

const draft = (title: string): NoteDraft => ({
  title,
  content: "",
  isPinned: false,
  background: null,
  tagIds: [],
  reminder: null,
});
const note = (id: string, title: string, version: number) =>
  ({
    id,
    title,
    content: "",
    version,
    isPinned: false,
    background: null,
    tagIds: [],
    reminder: null,
  }) as unknown as Note;
const settle = () => new Promise((resolve) => setTimeout(resolve, 5));

describe("the offline outbox", () => {
  beforeEach(() => {
    store.clear();
    saveNote.mockReset();
    createNote.mockReset();
    useAuthStore.setState({ user: { id: "u1" } as never });
    useSyncStatus.setState({ online: true });
  });
  afterEach(() => vi.useRealTimers());

  it("keeps an edit the server can't be reached for, and drops it once saved", async () => {
    saveNote.mockResolvedValueOnce({
      status: "failed",
      httpStatus: null,
      retryable: true,
    });
    const { queue } = noteSaveQueue("a");
    queue.push(draft("Offline"));
    await settle();
    expect(readOutbox().a?.draft.title).toBe("Offline");

    saveNote.mockResolvedValueOnce({
      status: "saved",
      note: note("a", "Offline", 2),
    });
    queue.retryNow();
    await settle();
    expect(readOutbox().a).toBeUndefined();
  });

  it("creates a note made offline after a reload, then forgets it", async () => {
    writeOutboxEntry("b", {
      draft: draft("Made offline"),
      base: null,
      create: true,
    });
    createNote.mockResolvedValueOnce(note("b", "Made offline", 1));
    const client = new QueryClient();
    client.setQueryData(["notes", null], []);
    restoreOutbox(client, "u1");
    expect(
      (client.getQueryData(["notes", null]) as Note[]).map((n) => n.id),
    ).toEqual(["b"]);
    await settle();
    expect(createNote).toHaveBeenCalledWith(
      expect.objectContaining({ id: "b", title: "Made offline" }),
    );
    expect(saveNote).not.toHaveBeenCalled();
    expect(readOutbox().b).toBeUndefined();
  });

  it("holds edits while offline and sends them once back", async () => {
    useSyncStatus.setState({ online: false });
    const { queue } = noteSaveQueue("c");
    queue.push(draft("Offline"));
    await settle();
    expect(saveNote).not.toHaveBeenCalled();
    expect(await allSaved()).toBe(false);

    saveNote.mockResolvedValueOnce({
      status: "saved",
      note: note("c", "Offline", 2),
    });
    useSyncStatus.setState({ online: true });
    retryAllSaves();
    await settle();
    expect(saveNote).toHaveBeenCalledTimes(1);
    expect(await allSaved()).toBe(true);
  });

  it("keeps text changed on both sides as a conflict copy", async () => {
    vi.useFakeTimers({ toFake: ["Date"] });
    vi.setSystemTime(new Date(2026, 10, 3, 12));
    const withText = (content: string): NoteDraft => ({
      ...draft("Shopping"),
      content,
    });
    writeOutboxEntry("d", {
      draft: { ...withText("mine"), isPinned: true },
      base: withText("before"),
      baseVersion: 1,
    });
    saveNote.mockResolvedValueOnce({
      status: "conflict",
      serverNote: { ...note("d", "Shopping", 2), content: "theirs" },
    });
    saveNote.mockResolvedValueOnce({
      status: "saved",
      note: { ...note("d", "Shopping", 3), content: "theirs", isPinned: true },
    });
    createNote.mockImplementationOnce(async (data) => ({
      ...note(data.id, "(conflict web 2026-11-03) Shopping", 1),
      content: "mine",
    }));
    const client = new QueryClient();
    client.setQueryData(["notes", null], [note("d", "Shopping", 2)]);
    restoreOutbox(client, "u1");
    await settle();
    await settle();

    expect(createNote).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "(conflict web 2026-11-03) Shopping",
        content: "mine",
      }),
    );
    // The note keeps the other text, with the pin set here.
    expect(saveNote).toHaveBeenLastCalledWith(
      "d",
      expect.objectContaining({ content: "theirs", isPinned: true }),
    );
    expect(await allSaved()).toBe(true);
  });
});
