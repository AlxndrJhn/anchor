import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  connectSharedNoteEvents,
  sharedNoteEventsUrl,
} from "./shared-note-events";

class FakeSocket {
  onopen: (() => void) | null = null;
  onmessage: ((event: { data: string }) => void) | null = null;
  onclose: ((event: { code: number }) => void) | null = null;
  close = vi.fn(() => this.onclose?.({ code: 1000 }));
  constructor(readonly url: string) {}
  open() {
    this.onopen?.();
  }
  message(data: unknown) {
    this.onmessage?.({ data: JSON.stringify(data) });
  }
  drop(code = 1006) {
    this.onclose?.({ code });
  }
}

describe("sharedNoteEventsUrl", () => {
  it("uses wss on https and ws on http, at the page's host", () => {
    expect(
      sharedNoteEventsUrl("a_b-1", { protocol: "https:", host: "n.example" }),
    ).toBe("wss://n.example/api/shared/a_b-1/events");
    expect(
      sharedNoteEventsUrl("t", { protocol: "http:", host: "localhost:3000" }),
    ).toBe("ws://localhost:3000/api/shared/t/events");
  });
});

describe("connectSharedNoteEvents", () => {
  let sockets: FakeSocket[];
  const onChange = vi.fn();
  const onConnectedChange = vi.fn();

  beforeEach(() => {
    vi.useFakeTimers();
    sockets = [];
    onChange.mockClear();
    onConnectedChange.mockClear();
  });
  afterEach(() => vi.useRealTimers());

  const connect = () =>
    connectSharedNoteEvents("tok", {
      onChange,
      onConnectedChange,
      createSocket: (url) => {
        const socket = new FakeSocket(url);
        sockets.push(socket);
        return socket as unknown as WebSocket;
      },
      random: () => 0.5,
      location: { protocol: "https:", host: "n.example" },
    });

  it("reloads once connected, and on every message", () => {
    connect();
    expect(sockets[0].url).toBe("wss://n.example/api/shared/tok/events");

    sockets[0].open();
    expect(onConnectedChange).toHaveBeenLastCalledWith(true);
    expect(onChange).toHaveBeenCalledTimes(1);

    sockets[0].message({ type: "changed" });
    expect(onChange).toHaveBeenCalledTimes(2);
  });

  it("falls back to polling while away and reconnects with backoff", () => {
    connect();
    sockets[0].open();
    sockets[0].drop();
    expect(onConnectedChange).toHaveBeenLastCalledWith(false);

    vi.advanceTimersByTime(999);
    expect(sockets).toHaveLength(1);
    vi.advanceTimersByTime(1);
    expect(sockets).toHaveLength(2);

    // Refused again: the wait doubles.
    sockets[1].drop();
    vi.advanceTimersByTime(1_999);
    expect(sockets).toHaveLength(2);
    vi.advanceTimersByTime(1);
    expect(sockets).toHaveLength(3);
  });

  it("stops for good when the link is turned off, reloading to show it", () => {
    connect();
    sockets[0].open();
    onChange.mockClear();

    sockets[0].message({ type: "gone" });
    sockets[0].drop(4404);

    expect(onChange).toHaveBeenCalledTimes(2);
    vi.advanceTimersByTime(120_000);
    expect(sockets).toHaveLength(1);
  });

  it("closes without reconnecting", () => {
    const stream = connect();
    sockets[0].open();
    onConnectedChange.mockClear();

    stream.close();

    expect(sockets[0].close).toHaveBeenCalled();
    vi.advanceTimersByTime(120_000);
    expect(sockets).toHaveLength(1);
    expect(onConnectedChange).not.toHaveBeenCalled();
  });
});
