import Delta, { type Op } from 'quill-delta';

export interface CollabEntry {
  rev: number;
  ops: Op[];
  sid: string;
  id: number;
}

export class InvalidCollabOp extends Error {}

/** Ops older than this can't be rebased; their client gets the whole text. */
const HISTORY_LIMIT = 2000;

/** Who the server's own changes (from outside the session) are by. */
export const SERVER_SID = 'server';

export const parseNoteContent = (content: string | null | undefined): Delta => {
  const fallback = () => {
    const text = content ?? '';
    return new Delta().insert(text.endsWith('\n') ? text : `${text}\n`);
  };
  if (!content) {
    return new Delta().insert('\n');
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    return fallback();
  }
  const ops = Array.isArray(parsed)
    ? (parsed as Op[])
    : (parsed as { ops?: Op[] } | null)?.ops;
  if (!Array.isArray(ops)) {
    return fallback();
  }
  // Composing merges neighbours, so every client counts the same positions.
  const doc = new Delta().compose(new Delta(ops));
  return endsWithNewline(doc) ? doc : doc.insert('\n');
};

export const stringifyNoteContent = (doc: Delta): string =>
  JSON.stringify({ ops: doc.ops });

const endsWithNewline = (doc: Delta): boolean => {
  const last = doc.ops[doc.ops.length - 1]?.insert;
  return typeof last === 'string' && last.endsWith('\n');
};

/** What a change reads of the text: it can't reach past the end. */
const consumedLength = (ops: Op[]): number => {
  let consumed = 0;
  for (const op of ops) {
    if (typeof op.retain === 'number') {
      consumed += op.retain;
    } else if (typeof op.delete === 'number') {
      consumed += op.delete;
    }
  }
  return consumed;
};

export const validateOps = (value: unknown): Op[] => {
  if (!Array.isArray(value)) {
    throw new InvalidCollabOp('ops must be a list');
  }
  for (const op of value as Op[]) {
    const kinds = [op?.insert, op?.retain, op?.delete].filter(
      (part) => part !== undefined,
    );
    const isValid =
      kinds.length === 1 &&
      (op.insert === undefined ||
        typeof op.insert === 'string' ||
        (typeof op.insert === 'object' && op.insert !== null)) &&
      (op.retain === undefined ||
        (Number.isInteger(op.retain) && (op.retain as number) > 0)) &&
      (op.delete === undefined ||
        (Number.isInteger(op.delete) && op.delete > 0));
    if (!isValid) {
      throw new InvalidCollabOp('Not a text change');
    }
  }
  return value as Op[];
};

/**
 * One note's text and the order of the changes made to it. Clients send a
 * change against the revision they last saw; it's rebased over whatever
 * arrived since, and everyone applies the result in the same order.
 */
export class CollabDocument {
  private readonly history: CollabEntry[] = [];
  rev = 0;

  constructor(public doc: Delta) {}

  /** The rebased change, or null when this one was applied before. */
  applyClient(
    ops: Op[],
    baseRev: number,
    sid: string,
    id: number,
  ): CollabEntry | { duplicateOf: number } {
    const earlier = this.history.find((e) => e.sid === sid && e.id === id);
    if (earlier) {
      return { duplicateOf: earlier.rev };
    }
    const concurrent = this.since(baseRev);
    if (!concurrent) {
      throw new InvalidCollabOp('Change is based on a text too old');
    }
    let rebased = new Delta(ops);
    for (const entry of concurrent) {
      rebased = new Delta(entry.ops).transform(rebased, true);
    }
    return this.apply(rebased, sid, id);
  }

  /** A change made outside the session, over the text as it stands. */
  applyServer(change: Delta): CollabEntry | null {
    if (change.ops.length === 0) {
      return null;
    }
    return this.apply(change, SERVER_SID, this.rev + 1);
  }

  /** The changes after [rev], or null once they're no longer kept. */
  since(rev: number): CollabEntry[] | null {
    if (!Number.isInteger(rev) || rev < 0 || rev > this.rev) {
      return null;
    }
    const missing = this.rev - rev;
    if (missing > this.history.length) {
      return null;
    }
    return missing === 0 ? [] : this.history.slice(-missing);
  }

  /**
   * A caret from a client that had seen [rev] and all of its own changes, in
   * the text as it stands now.
   */
  rebasePosition(index: number, rev: number, sid: string): number {
    const concurrent = this.since(rev) ?? [];
    let at = index;
    for (const entry of concurrent) {
      if (entry.sid !== sid) {
        at = new Delta(entry.ops).transformPosition(at);
      }
    }
    return Math.min(Math.max(at, 0), this.doc.length() - 1);
  }

  private apply(change: Delta, sid: string, id: number): CollabEntry {
    if (consumedLength(change.ops) > this.doc.length()) {
      throw new InvalidCollabOp('Change reaches past the end of the text');
    }
    const next = this.doc.compose(change);
    if (!endsWithNewline(next)) {
      throw new InvalidCollabOp('The text must end with a line break');
    }
    this.doc = next;
    this.rev += 1;
    const entry = { rev: this.rev, ops: change.ops, sid, id };
    this.history.push(entry);
    if (this.history.length > HISTORY_LIMIT) {
      this.history.shift();
    }
    return entry;
  }
}
