import Delta, { type Op } from "quill-delta";

/** While a dropped connection may still come back, edits wait for it. */
const FALLBACK_AFTER_MS = 15_000;
const MIN_RETRY_MS = 1_000;
const MAX_RETRY_MS = 60_000;
const CURSOR_THROTTLE_MS = 60;
const DRAIN_TIMEOUT_MS = 5_000;
const MAX_RESETS = 3;

const CLOSE_GONE = 4404;
const CLOSE_UNAUTHORIZED = 4401;
const CLOSE_FULL = 4409;

// biome-ignore lint/suspicious/noExplicitAny: messages as the server sends them.
type ServerMessage = Record<string, any>;

export interface CollabPeer {
  id: string;
  name: string;
  canEdit: boolean;
  index: number | null;
  length: number;
  rev: number;
}

export interface CollabEditor {
  /** The text as it stands now. */
  getDoc: () => Delta;
  /** Applies others' change; it must not come back through localChange. */
  apply: (change: Delta) => void;
}

export interface CollabOptions {
  target: { link: string } | { noteId: string; getJwt: () => string | null };
  refreshJwt?: () => Promise<boolean>;
  /** The last saved text when the editor holds edits beyond it, else null. */
  getUnsavedBase: () => Delta | null;
  onLive?: (isLive: boolean) => void;
  onMeta?: (meta: { title?: string; background?: string | null }) => void;
  onCanEdit?: (canEdit: boolean) => void;
  /** Everything typed so far has reached the server, or hasn't. */
  onPending?: (isPending: boolean) => void;
  onSaved?: (version: number) => void;
  /** Something about the note may have changed: load it again. */
  onChanged?: () => void;
  onGone?: () => void;
  webSocket?: typeof WebSocket;
  url?: string;
  random?: () => number;
}

/** The same text and formatting, whatever order its attributes were set in. */
const canonicalOps = (doc: Delta) =>
  JSON.stringify(
    new Delta().compose(doc).ops.map(({ insert, attributes }) => ({
      insert,
      ...(attributes
        ? {
            attributes: Object.fromEntries(
              Object.entries(attributes).sort(([a], [b]) =>
                a < b ? -1 : a > b ? 1 : 0,
              ),
            ),
          }
        : {}),
    })),
  );

const sameDoc = (a: Delta, b: Delta) => canonicalOps(a) === canonicalOps(b);

/**
 * This client's end of editing a note together. A change goes up one at a
 * time: what's typed while one is on its way waits, and both are rebased over
 * whatever arrives from others, so every client ends up with the same text.
 */
export class CollabSession {
  private readonly sid =
    globalThis.crypto?.randomUUID?.() ?? `${Date.now()}-${Math.random()}`;
  private readonly peers = new Map<string, CollabPeer>();
  private editor: CollabEditor | null = null;
  private ws: WebSocket | null = null;
  private isOpenForEdits = false;
  private isClosed = false;
  private isGivenUp = false;
  private live = false;
  private canEdit = false;
  private pending = false;
  private epoch: string | undefined;
  private rev = 0;
  /** The text at `rev`, without what's on its way or waiting. */
  private shadow: Delta | null = null;
  private flight: { id: number; change: Delta } | null = null;
  private waiting = new Delta();
  private nextId = 1;
  private attempt = 0;
  private resets = 0;
  private hasRefreshedJwt = false;
  private retryTimer: ReturnType<typeof setTimeout> | undefined;
  private fallbackTimer: ReturnType<typeof setTimeout> | undefined;
  private cursorTimer: ReturnType<typeof setTimeout> | undefined;
  private cursor: { index: number; length: number } | null = null;
  private cursorDirty = false;
  private drained: (() => void) | null = null;
  private readonly peerListeners = new Set<(peers: CollabPeer[]) => void>();

  private readonly options: CollabOptions;

  constructor(options: CollabOptions) {
    this.options = options;
  }

  get isLive(): boolean {
    return this.live;
  }

  /** While true, the editor's changes go here and nowhere else. */
  get isTracking(): boolean {
    return this.shadow !== null;
  }

  get serverDoc(): Delta | null {
    return this.shadow;
  }

  /** Calls back with everyone else now and on every change; returns the stop. */
  listenToPeers(listener: (peers: CollabPeer[]) => void): () => void {
    this.peerListeners.add(listener);
    listener([...this.peers.values()]);
    return () => {
      this.peerListeners.delete(listener);
    };
  }

  attachEditor(editor: CollabEditor): void {
    this.editor = editor;
    if (!this.ws && !this.isClosed && !this.isGivenUp) this.connect();
  }

  detachEditor(): void {
    this.editor = null;
  }

  localChange(change: Delta): void {
    if (!this.isTracking || change.ops.length === 0) return;
    this.waiting = this.waiting.compose(change);
    this.shiftPeers(change, Number.POSITIVE_INFINITY);
    this.flush();
    this.updatePending();
  }

  /** Null when this client's caret isn't in the text. */
  setCursor(cursor: { index: number; length: number } | null): void {
    this.cursor = cursor;
    this.cursorDirty = true;
    if (this.cursorTimer === undefined) {
      this.cursorTimer = setTimeout(() => {
        this.cursorTimer = undefined;
        this.sendCursor();
      }, CURSOR_THROTTLE_MS);
    }
  }

  setMeta(meta: { title?: string; background?: string | null }): void {
    if (this.isOpenForEdits && this.canEdit) this.send({ t: "meta", ...meta });
  }

  /** Waits a moment for what's on its way, then leaves. */
  async close(): Promise<void> {
    if (this.isClosed) return;
    if (this.flight || this.waiting.ops.length) {
      await Promise.race([
        new Promise<void>((resolve) => {
          this.drained = resolve;
        }),
        new Promise<void>((resolve) => setTimeout(resolve, DRAIN_TIMEOUT_MS)),
      ]);
    }
    this.isClosed = true;
    this.stopTimers();
    const ws = this.ws;
    this.ws = null;
    this.editor = null;
    ws?.close(1000);
  }

  private stopTimers() {
    clearTimeout(this.retryTimer);
    clearTimeout(this.fallbackTimer);
    clearTimeout(this.cursorTimer);
    this.cursorTimer = undefined;
  }

  private connect(): void {
    const WS = this.options.webSocket ?? globalThis.WebSocket;
    if (!WS || !this.editor) return;
    const url =
      this.options.url ??
      `${window.location.protocol === "https:" ? "wss:" : "ws:"}//${window.location.host}/api/collab`;
    let ws: WebSocket;
    try {
      ws = new WS(url);
    } catch {
      this.scheduleRetry();
      return;
    }
    this.ws = ws;
    ws.onopen = () => {
      const { target } = this.options;
      this.sendOn(ws, {
        t: "join",
        sid: this.sid,
        ...("link" in target
          ? { link: target.link }
          : { noteId: target.noteId, jwt: target.getJwt() }),
        ...(this.epoch ? { epoch: this.epoch, rev: this.rev } : {}),
      });
    };
    ws.onmessage = (event) => {
      if (this.ws !== ws) return;
      try {
        this.receive(JSON.parse(String(event.data)));
      } catch {
        // The texts no longer line up: start over from the server's.
        this.startOver();
      }
    };
    ws.onclose = (event) => {
      if (this.ws === ws) this.dropped(event.code);
    };
  }

  private dropped(code: number): void {
    this.ws = null;
    this.isOpenForEdits = false;
    this.peers.clear();
    this.tellPeers();
    if (this.isClosed) return;
    if (code === CLOSE_GONE) {
      this.giveUp();
      this.options.onGone?.();
      return;
    }
    if (code === CLOSE_FULL) {
      this.giveUp();
      return;
    }
    if (code === CLOSE_UNAUTHORIZED) {
      const { refreshJwt } = this.options;
      if (!refreshJwt || this.hasRefreshedJwt) {
        this.giveUp();
        return;
      }
      this.hasRefreshedJwt = true;
      void refreshJwt().then((ok) => {
        if (ok) this.scheduleRetry();
        else this.giveUp();
      });
      return;
    }
    if (this.live && this.fallbackTimer === undefined) {
      this.fallbackTimer = setTimeout(() => this.fallBack(), FALLBACK_AFTER_MS);
    }
    this.scheduleRetry();
  }

  private scheduleRetry(): void {
    if (this.isClosed || this.isGivenUp) return;
    const backoff = Math.min(MIN_RETRY_MS * 2 ** this.attempt, MAX_RETRY_MS);
    this.attempt = Math.min(this.attempt + 1, 6);
    const jitter = 0.75 + (this.options.random ?? Math.random)() * 0.5;
    clearTimeout(this.retryTimer);
    this.retryTimer = setTimeout(
      () => this.connect(),
      Math.round(backoff * jitter),
    );
  }

  // The host's own saving takes over, from the text on screen.
  private fallBack(): void {
    clearTimeout(this.fallbackTimer);
    this.fallbackTimer = undefined;
    this.shadow = null;
    this.flight = null;
    this.waiting = new Delta();
    this.epoch = undefined;
    this.setLive(false);
    this.updatePending();
  }

  private giveUp(): void {
    this.isGivenUp = true;
    this.stopTimers();
    const ws = this.ws;
    this.ws = null;
    ws?.close(1000);
    this.fallBack();
    this.drained?.();
  }

  private startOver(): void {
    this.resets += 1;
    if (this.resets > MAX_RESETS) {
      this.giveUp();
      return;
    }
    this.epoch = undefined;
    const ws = this.ws;
    this.ws = null;
    this.isOpenForEdits = false;
    ws?.close(1000);
    this.scheduleRetry();
  }

  private setLive(isLive: boolean): void {
    if (this.live === isLive) return;
    this.live = isLive;
    this.options.onLive?.(isLive);
  }

  private updatePending(): void {
    const isPending = !!this.flight || this.waiting.ops.length > 0;
    if (isPending !== this.pending) {
      this.pending = isPending;
      this.options.onPending?.(isPending);
    }
    if (!isPending && this.drained) {
      const drained = this.drained;
      this.drained = null;
      drained();
    }
  }

  private receive(message: ServerMessage): void {
    switch (message.t) {
      case "hello":
        this.hello(message);
        break;
      case "ack":
        this.ack(message.id, message.rev);
        break;
      case "nack":
        this.flight = null;
        this.waiting = new Delta();
        this.updatePending();
        break;
      case "op":
        this.remote(new Delta(message.ops as Op[]), message.rev);
        break;
      case "peer":
        this.peers.set(message.id, this.peerFrom(message));
        this.tellPeers();
        break;
      case "peerGone":
        this.peers.delete(message.id);
        this.tellPeers();
        break;
      case "cursor": {
        const peer = this.peers.get(message.id);
        if (peer) {
          const here = this.pendingChange();
          peer.index =
            message.index === null
              ? null
              : here.transformPosition(message.index);
          peer.length = message.length ?? 0;
          peer.rev = message.rev;
          this.tellPeers();
        }
        break;
      }
      case "meta":
        if (typeof message.canEdit === "boolean") {
          this.canEdit = message.canEdit;
          this.options.onCanEdit?.(message.canEdit);
        }
        if ("title" in message || "background" in message) {
          this.options.onMeta?.({
            ...("title" in message ? { title: message.title } : {}),
            ...("background" in message
              ? { background: message.background }
              : {}),
          });
        }
        break;
      case "saved":
        this.options.onSaved?.(message.version);
        this.options.onChanged?.();
        break;
      case "changed":
        this.options.onChanged?.();
        break;
    }
  }

  private peerFrom(message: ServerMessage): CollabPeer {
    return {
      id: message.id,
      name: message.name ?? "",
      canEdit: !!message.canEdit,
      index: message.index ?? null,
      length: message.length ?? 0,
      rev: message.rev ?? 0,
    };
  }

  private pendingChange(): Delta {
    return (this.flight?.change ?? new Delta()).compose(this.waiting);
  }

  private hello(message: ServerMessage): void {
    const editor = this.editor;
    if (!editor) return;
    clearTimeout(this.fallbackTimer);
    this.fallbackTimer = undefined;
    this.attempt = 0;
    this.hasRefreshedJwt = false;
    this.epoch = message.epoch;
    this.canEdit = !!message.canEdit;
    this.options.onCanEdit?.(this.canEdit);

    if (Array.isArray(message.catchup) && this.shadow) {
      for (const entry of message.catchup) {
        if (entry.sid !== this.sid) {
          this.remote(new Delta(entry.ops as Op[]), entry.rev);
        } else if (this.flight?.id === entry.id) {
          this.ack(entry.id, entry.rev);
        } else {
          // An older change of ours, acknowledged before.
          this.shadow = this.shadow.compose(new Delta(entry.ops as Op[]));
          this.rev = entry.rev;
        }
      }
    } else {
      this.adopt(new Delta(message.doc as Op[]), message.rev, editor);
    }

    this.isOpenForEdits = true;
    this.peers.clear();
    for (const peer of message.peers ?? []) {
      this.peers.set(peer.id, this.peerFrom(peer));
    }
    this.tellPeers();
    this.setLive(true);
    this.options.onMeta?.({
      title: message.title,
      background: message.background,
    });
    if (typeof message.version === "number") {
      this.options.onSaved?.(message.version);
    }

    if (this.flight) {
      // Lost with the connection: if it did arrive, the server knows its id.
      this.send({
        t: "op",
        rev: this.rev,
        id: this.flight.id,
        ops: this.flight.change.ops,
      });
    }
    this.flush();
    this.updatePending();
    this.cursorDirty = true;
    this.sendCursor();
  }

  // Everything's rebased from the last text both sides knew onto the server's.
  private adopt(server: Delta, rev: number, editor: CollabEditor): void {
    const here = editor.getDoc();
    let from: Delta;
    let mine: Delta;
    if (this.shadow) {
      from = this.shadow;
      mine = this.pendingChange();
    } else {
      const base = this.options.getUnsavedBase();
      from = base ?? here;
      mine = base ? base.diff(here) : new Delta();
    }
    this.flight = null;
    if (sameDoc(from.compose(mine), server)) {
      // Nothing to do: what's here arrived, even if we weren't told.
      this.waiting = new Delta();
    } else {
      const theirs = from.diff(server);
      const toApply = mine.transform(theirs, false);
      this.waiting = theirs.transform(mine, true);
      if (toApply.ops.length) editor.apply(toApply);
    }
    this.shadow = server;
    this.rev = rev;
    const expected = server.compose(this.waiting).length();
    if (editor.getDoc().length() !== expected) this.startOver();
  }

  private ack(id: number, rev: number): void {
    if (!this.flight || this.flight.id !== id || !this.shadow) return;
    this.shadow = this.shadow.compose(this.flight.change);
    this.rev = rev;
    this.flight = null;
    this.flush();
    this.updatePending();
    this.checkLinedUp();
    if (this.cursorDirty) this.sendCursor();
  }

  private remote(change: Delta, rev: number): void {
    if (!this.shadow || !this.editor) return;
    this.shadow = this.shadow.compose(change);
    this.rev = rev;
    let incoming = change;
    if (this.flight) {
      const flight = this.flight.change;
      this.flight.change = incoming.transform(flight, true);
      incoming = flight.transform(incoming, false);
    }
    const waiting = this.waiting;
    this.waiting = incoming.transform(waiting, true);
    incoming = waiting.transform(incoming, false);
    if (incoming.ops.length) this.editor.apply(incoming);
    this.shiftPeers(incoming, rev);
    this.checkLinedUp();
  }

  private shiftPeers(change: Delta, rev: number): void {
    for (const peer of this.peers.values()) {
      // A caret sent after this change already allows for it.
      if (peer.index === null || rev <= peer.rev) continue;
      const end = change.transformPosition(peer.index + peer.length);
      peer.index = change.transformPosition(peer.index);
      peer.length = Math.max(end - peer.index, 0);
    }
    this.tellPeers();
  }

  private checkLinedUp(): void {
    if (this.flight || this.waiting.ops.length || !this.shadow || !this.editor)
      return;
    if (this.editor.getDoc().length() !== this.shadow.length()) {
      this.startOver();
    }
  }

  private flush(): void {
    if (
      this.flight ||
      !this.isOpenForEdits ||
      !this.canEdit ||
      this.waiting.ops.length === 0
    )
      return;
    this.flight = { id: this.nextId++, change: this.waiting };
    this.waiting = new Delta();
    this.send({
      t: "op",
      rev: this.rev,
      id: this.flight.id,
      ops: this.flight.change.ops,
    });
  }

  private sendCursor(): void {
    // Its position counts what's typed, which the server must have first.
    if (
      !this.cursorDirty ||
      !this.isOpenForEdits ||
      !this.canEdit ||
      this.waiting.ops.length
    )
      return;
    this.cursorDirty = false;
    this.send({
      t: "cursor",
      index: this.cursor?.index ?? null,
      length: this.cursor?.length ?? 0,
      rev: this.rev,
    });
  }

  private tellPeers(): void {
    const peers = [...this.peers.values()];
    for (const listener of this.peerListeners) listener(peers);
  }

  private send(message: object): void {
    if (this.ws) this.sendOn(this.ws, message);
  }

  private sendOn(ws: WebSocket, message: object): void {
    if (ws.readyState === 1) ws.send(JSON.stringify(message));
  }
}
