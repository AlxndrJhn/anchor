import { readFileSync } from "node:fs";
import { join } from "node:path";
import Delta, { type Op } from "quill-delta";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { type CollabEditor, type CollabPeer, CollabSession } from "./session";

/** Plays the server: one text, one order of changes, delivered when told. */
class FakeServer {
  doc = new Delta().insert("hello\n");
  rev = 0;
  epoch = "e1";
  history: { rev: number; ops: Op[]; sid: string; id: number }[] = [];
  sockets: FakeSocket[] = [];

  receive(socket: FakeSocket, message: Record<string, any>) {
    if (message.t === "join") {
      socket.sid = message.sid;
      const catchup =
        message.epoch === this.epoch
          ? this.history.filter((entry) => entry.rev > message.rev)
          : null;
      socket.deliver({
        t: "hello",
        me: `peer-${message.sid}`,
        epoch: this.epoch,
        rev: this.rev,
        canEdit: true,
        title: "T",
        background: null,
        peers: [],
        ...(catchup ? { catchup } : { doc: this.doc.ops }),
      });
    } else if (message.t === "op") {
      const earlier = this.history.find(
        (entry) => entry.sid === socket.sid && entry.id === message.id,
      );
      if (earlier) {
        socket.deliver({ t: "ack", id: message.id, rev: earlier.rev });
        return;
      }
      let change = new Delta(message.ops);
      for (const entry of this.history.filter((e) => e.rev > message.rev)) {
        change = new Delta(entry.ops).transform(change, true);
      }
      this.doc = this.doc.compose(change);
      this.rev += 1;
      this.history.push({
        rev: this.rev,
        ops: change.ops,
        sid: socket.sid,
        id: message.id,
      });
      const rev = this.rev;
      for (const other of this.sockets) {
        if (other !== socket && other.readyState === 1) {
          other.deliver({ t: "op", rev, ops: change.ops });
        }
      }
      socket.deliver({ t: "ack", id: message.id, rev });
    }
  }
}

class FakeSocket {
  static server: FakeServer;
  static holdDelivery = false;
  readyState = 0;
  sid = "";
  inbox: object[] = [];
  outbox: Record<string, any>[] = [];
  onopen: (() => void) | null = null;
  onmessage: ((event: { data: string }) => void) | null = null;
  onclose: ((event: { code: number }) => void) | null = null;

  constructor() {
    FakeSocket.server.sockets.push(this);
    setTimeout(() => {
      this.readyState = 1;
      this.onopen?.();
    });
  }

  send(raw: string) {
    this.outbox.push(JSON.parse(raw));
    if (!FakeSocket.holdDelivery) this.pumpOut();
  }

  pumpOut() {
    for (const message of this.outbox.splice(0)) {
      FakeSocket.server.receive(this, message);
    }
  }

  deliver(message: object) {
    this.inbox.push(message);
    if (!FakeSocket.holdDelivery) this.pumpIn();
  }

  pumpIn() {
    for (const message of this.inbox.splice(0)) {
      this.onmessage?.({ data: JSON.stringify(message) });
    }
  }

  close(code = 1000) {
    this.readyState = 3;
    this.onclose?.({ code });
  }

  /** The connection drops with what was on its way. */
  drop() {
    this.inbox = [];
    this.outbox = [];
    this.close(1006);
  }
}

class FakeEditor implements CollabEditor {
  constructor(
    public doc: Delta,
    private readonly session: () => CollabSession,
  ) {}
  getDoc = () => this.doc;
  apply = (change: Delta) => {
    this.doc = this.doc.compose(change);
  };
  type(change: Delta) {
    this.doc = this.doc.compose(change);
    this.session().localChange(change);
  }
}

const textOf = (doc: Delta) =>
  doc.ops
    .map((op) => (typeof op.insert === "string" ? op.insert : ""))
    .join("");

describe("CollabSession", () => {
  let server: FakeServer;

  const open = async (doc = new Delta().insert("hello\n")) => {
    const onLive = vi.fn();
    const onPending = vi.fn();
    const session = new CollabSession({
      target: { link: "tok" },
      getUnsavedBase: () => null,
      onLive,
      onPending,
      webSocket: FakeSocket as unknown as typeof WebSocket,
      url: "ws://test/api/collab",
      random: () => 0.5,
    });
    const editor = new FakeEditor(doc, () => session);
    session.attachEditor(editor);
    await vi.advanceTimersByTimeAsync(1);
    return { session, editor, onLive, onPending };
  };

  beforeEach(() => {
    vi.useFakeTimers();
    server = new FakeServer();
    FakeSocket.server = server;
    FakeSocket.holdDelivery = false;
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("goes live with the server's text", async () => {
    server.doc = new Delta().insert("newer text\n");
    const { editor, session, onLive } = await open();
    expect(textOf(editor.doc)).toBe("newer text\n");
    expect(session.isLive).toBe(true);
    expect(onLive).toHaveBeenCalledWith(true);
  });

  it("keeps edits made before joining, over the server's newer text", async () => {
    server.doc = new Delta().insert("hello world\n");
    const base = new Delta().insert("hello\n");
    const session = new CollabSession({
      target: { link: "tok" },
      getUnsavedBase: () => base,
      webSocket: FakeSocket as unknown as typeof WebSocket,
      url: "ws://test/api/collab",
    });
    const editor = new FakeEditor(
      new Delta().insert("Ahello\n"),
      () => session,
    );
    session.attachEditor(editor);
    await vi.advanceTimersByTimeAsync(1);
    expect(textOf(editor.doc)).toBe("Ahello world\n");
    expect(textOf(server.doc)).toBe("Ahello world\n");
  });

  it("merges two people typing at once", async () => {
    const one = await open();
    const two = await open();
    FakeSocket.holdDelivery = true;

    one.editor.type(new Delta().insert("A"));
    two.editor.type(new Delta().retain(5).insert("B"));
    two.editor.type(new Delta().retain(6).insert("C"));

    FakeSocket.holdDelivery = false;
    for (let turn = 0; turn < 6; turn++) {
      for (const socket of server.sockets) {
        socket.pumpOut();
        socket.pumpIn();
      }
    }
    expect(textOf(one.editor.doc)).toBe("AhelloBC\n");
    expect(one.editor.doc.ops).toEqual(two.editor.doc.ops);
    expect(server.doc.ops).toEqual(one.editor.doc.ops);
  });

  it("sends one change at a time", async () => {
    const { editor } = await open();
    FakeSocket.holdDelivery = true;
    editor.type(new Delta().insert("a"));
    editor.type(new Delta().retain(1).insert("b"));
    editor.type(new Delta().retain(2).insert("c"));
    const socket = server.sockets[0];
    expect(socket.outbox.filter((m) => m.t === "op")).toHaveLength(1);
    FakeSocket.holdDelivery = false;
    socket.pumpOut();
    socket.pumpIn();
    expect(textOf(server.doc)).toBe("abchello\n");
  });

  it("says when everything has reached the server", async () => {
    const { editor, onPending } = await open();
    FakeSocket.holdDelivery = true;
    editor.type(new Delta().insert("a"));
    expect(onPending).toHaveBeenLastCalledWith(true);
    FakeSocket.holdDelivery = false;
    const socket = server.sockets[0];
    socket.pumpOut();
    socket.pumpIn();
    expect(onPending).toHaveBeenLastCalledWith(false);
  });

  it("doesn't apply a change twice when its answer was lost", async () => {
    const { editor } = await open();
    FakeSocket.holdDelivery = true;
    const socket = server.sockets[0];
    editor.type(new Delta().insert("a"));
    // It arrives, but the connection drops before the answer does.
    socket.pumpOut();
    socket.drop();
    FakeSocket.holdDelivery = false;

    await vi.advanceTimersByTimeAsync(2_000);
    expect(textOf(server.doc)).toBe("ahello\n");
    expect(textOf(editor.doc)).toBe("ahello\n");
  });

  it("keeps what's typed while disconnected", async () => {
    const { editor } = await open();
    const socket = server.sockets[0];
    socket.drop();
    editor.type(new Delta().insert("offline "));
    server.doc = server.doc.compose(new Delta().retain(5).insert("!"));
    server.rev += 1;
    server.history.push({
      rev: server.rev,
      ops: new Delta().retain(5).insert("!").ops,
      sid: "other",
      id: 1,
    });

    await vi.advanceTimersByTimeAsync(2_000);
    expect(textOf(editor.doc)).toBe("offline hello!\n");
    expect(server.doc.ops).toEqual(editor.doc.ops);
  });

  it("rebases what's waiting onto a server that started over", async () => {
    const { editor } = await open();
    const socket = server.sockets[0];
    socket.drop();
    editor.type(new Delta().insert("mine "));
    server.epoch = "e2";
    server.rev = 0;
    server.history = [];
    server.doc = new Delta().insert("hello there\n");

    await vi.advanceTimersByTimeAsync(2_000);
    expect(textOf(editor.doc)).toBe("mine hello there\n");
    expect(textOf(server.doc)).toBe("mine hello there\n");
  });

  it("hands saving back after a long loss of connection", async () => {
    const { session, editor, onLive } = await open();
    server.sockets[0].drop();
    server.receive = () => {};
    editor.type(new Delta().insert("a"));

    await vi.advanceTimersByTimeAsync(16_000);
    expect(onLive).toHaveBeenLastCalledWith(false);
    expect(session.isTracking).toBe(false);
    await session.close();
  });

  it("gives up when the note is gone, and says so", async () => {
    const onGone = vi.fn();
    const session = new CollabSession({
      target: { link: "tok" },
      getUnsavedBase: () => null,
      onGone,
      webSocket: FakeSocket as unknown as typeof WebSocket,
      url: "ws://test/api/collab",
    });
    session.attachEditor(
      new FakeEditor(new Delta().insert("x\n"), () => session),
    );
    await vi.advanceTimersByTimeAsync(1);
    server.sockets[0].close(4404);
    expect(onGone).toHaveBeenCalled();
    await vi.advanceTimersByTimeAsync(70_000);
    expect(server.sockets).toHaveLength(1);
  });

  it("moves others' carets over text that changes", async () => {
    const { session, editor } = await open();
    const socket = server.sockets[0];
    let peers: CollabPeer[] = [];
    session.listenToPeers((next) => {
      peers = next;
    });
    socket.deliver({
      t: "peer",
      id: "p",
      name: "Guest",
      canEdit: true,
      index: 3,
      length: 0,
      rev: 0,
    });
    expect(peers[0].index).toBe(3);

    editor.type(new Delta().insert("AB"));
    expect(peers[0].index).toBe(5);

    socket.deliver({ t: "op", rev: 2, ops: [{ insert: "Z" }] });
    expect(peers[0].index).toBe(6);
  });
});

describe("the shared vectors", () => {
  it("quill-delta answers as they recorded", () => {
    const vectors = JSON.parse(
      readFileSync(
        join(
          __dirname,
          "../../../../server/test/fixtures/collab-ot-vectors.json",
        ),
        "utf8",
      ),
    ) as Record<string, any>[];
    for (const vector of vectors) {
      const a = new Delta(vector.a);
      const b = new Delta(vector.b);
      expect(a.transform(b, true).ops).toEqual(vector.bOverA);
      expect(b.transform(a, false).ops).toEqual(vector.aOverB);
    }
  });
});
