import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/** `changed`: load the note again; `gone`: the link was turned off. */
export type SharedNoteEvent = 'changed' | 'gone';
type Listener = (event: SharedNoteEvent) => void;

/**
 * Tells the pages open on a note's share link that the note changed, so they
 * load it again at once instead of on their next poll. Like the sync events,
 * fan-out is in-process: it assumes the single-instance deployment.
 */
@Injectable()
export class SharedNoteEventsService {
  private readonly listeners = new Map<string, Set<Listener>>();

  constructor(private prisma: PrismaService) {}

  /** Calls `listener` whenever the note changes; the result unsubscribes. */
  subscribe(noteId: string, listener: Listener): () => void {
    let set = this.listeners.get(noteId);
    if (!set) {
      set = new Set();
      this.listeners.set(noteId, set);
    }
    set.add(listener);
    return () => {
      const current = this.listeners.get(noteId);
      if (!current) {
        return;
      }
      current.delete(listener);
      if (current.size === 0) {
        this.listeners.delete(noteId);
      }
    };
  }

  // Waits for the commit, so a page that reloads finds the change there.
  scheduleChanged(noteIds: Iterable<string>): void {
    const watched = [...new Set(noteIds)].filter((id) =>
      this.listeners.has(id),
    );
    if (watched.length === 0) {
      return;
    }
    this.prisma.afterCommit(() => {
      for (const noteId of watched) {
        this.changed(noteId);
      }
    });
  }

  changed(noteId: string): void {
    this.tell(noteId, 'changed');
  }

  /** The note's link was turned off: its pages stop listening. */
  gone(noteId: string): void {
    this.tell(noteId, 'gone');
  }

  listenerCount(noteId: string): number {
    return this.listeners.get(noteId)?.size ?? 0;
  }

  private tell(noteId: string, event: SharedNoteEvent): void {
    const set = this.listeners.get(noteId);
    if (!set) {
      return;
    }
    for (const listener of [...set]) {
      listener(event);
    }
  }
}
