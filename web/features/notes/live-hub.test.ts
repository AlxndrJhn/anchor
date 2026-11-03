import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import type { LiveImage } from "./live-images";

/**
 * Two devices, each its own copy of live-hub.ts, talking through a stand-in
 * for the server (every message to every window, as the sync stream does)
 * and a stand-in for WebRTC that connects an offer to its answer.
 */

type Hub = typeof import("./live-hub");

const hubs: Hub[] = [];
const sent: { kind: string; to?: { device: string } }[] = [];

vi.mock("@/lib/api/client", () => ({
  getJson: () => Promise.resolve({ iceServers: [] }),
  api: {
    post: (_url: string, { json }: { json: { kind: string } }) => {
      sent.push(json);
      setTimeout(() => {
        for (const hub of hubs) hub.receiveLiveSignal(structuredClone(json));
      }, 0);
      return Promise.resolve(new Response(null, { status: 204 }));
    },
  },
}));

class FakeTrack {
  stopped = false;
  enabled = true;
  constructor(readonly kind: "video" | "audio" = "video") {}
  listeners: (() => void)[] = [];
  stop() {
    this.stopped = true;
  }
  addEventListener(_: string, listener: () => void) {
    this.listeners.push(listener);
  }
  getSettings() {
    return { deviceId: "cam-1" };
  }
}

class FakeStream {
  tracks = [new FakeTrack()];
  constructor(tracks?: FakeTrack[]) {
    if (tracks) this.tracks = tracks;
  }
  getTracks() {
    return this.tracks;
  }
  getVideoTracks() {
    return this.tracks.filter((t) => t.kind === "video");
  }
  getAudioTracks() {
    return this.tracks.filter((t) => t.kind === "audio");
  }
  addTrack(track: FakeTrack) {
    this.tracks.push(track);
  }
}

const offers = new Map<string, FakePeer>();
let nextSdp = 0;

class FakePeer {
  connectionState = "new";
  signalingState = "stable";
  remoteDescription: { sdp: string } | null = null;
  stream: FakeStream | null = null;
  partner: FakePeer | null = null;
  ontrack: ((e: { streams: FakeStream[] }) => void) | null = null;
  onicecandidate: ((e: { candidate: null }) => void) | null = null;
  onconnectionstatechange: (() => void) | null = null;
  addTrack(_track: FakeTrack, stream: FakeStream) {
    this.stream = stream;
  }
  async createOffer() {
    return { type: "offer", sdp: `sdp-${nextSdp++}` };
  }
  async createAnswer() {
    return { type: "answer", sdp: `answer-${nextSdp++}` };
  }
  async setLocalDescription(d: { type: string; sdp: string }) {
    if (d.type === "offer") {
      offers.set(d.sdp, this);
      this.signalingState = "have-local-offer";
    }
  }
  async setRemoteDescription(d: { type: string; sdp: string }) {
    this.remoteDescription = d;
    if (d.type === "offer") {
      this.partner = offers.get(d.sdp) ?? null;
      if (this.partner) this.partner.partner = this;
    } else if (this.partner) {
      // The answer is in: both ends connect.
      this.signalingState = "stable";
      const viewer = this.partner;
      viewer.ontrack?.({ streams: [this.stream!] });
      for (const end of [this, viewer]) {
        end.connectionState = "connected";
        end.onconnectionstatechange?.();
      }
    }
  }
  async addIceCandidate() {}
  close() {
    if (this.connectionState === "closed") return;
    this.connectionState = "closed";
  }
}

function storage() {
  const items = new Map<string, string>();
  return {
    getItem: (key: string) => items.get(key) ?? null,
    setItem: (key: string, value: string) => items.set(key, value),
    removeItem: (key: string) => items.delete(key),
  };
}

const getUserMedia = vi.fn(async (constraints?: { video?: unknown }) =>
  constraints && !constraints.video
    ? new FakeStream([new FakeTrack("audio")])
    : new FakeStream(),
);

async function newDevice(): Promise<Hub> {
  localStorage.removeItem("anchor:live-device");
  vi.resetModules();
  const hub = await import("./live-hub");
  hub.liveDeviceId();
  hubs.push(hub);
  return hub;
}

const settle = async () => {
  for (let i = 0; i < 20; i++) await vi.advanceTimersByTimeAsync(1);
};

function imageOf(hub: Hub, source: LiveImage["source"] = "camera"): LiveImage {
  return { id: "live-1", source, device: hub.liveDeviceId(), label: "Desk" };
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.stubGlobal("localStorage", storage());
  vi.stubGlobal("RTCPeerConnection", FakePeer);
  vi.stubGlobal("MediaStream", FakeStream);
  vi.stubGlobal("window", { RTCPeerConnection: FakePeer });
  vi.stubGlobal("navigator", {
    userAgent: "Chrome/140 Windows",
    mediaDevices: { getUserMedia, getDisplayMedia: vi.fn() },
  });
  sent.length = 0;
  getUserMedia.mockClear();
});

afterEach(() => {
  for (const hub of hubs.splice(0)) hub.resetLiveHub();
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe("live hub", () => {
  it("shows another device's camera once asked", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    const camera = new FakeStream();
    desk.adoptSource("live-1", "note-1", "camera", camera as never);

    const views: string[] = [];
    phone.watchLive(imageOf(desk), "note-1", (view) => {
      views.push(view.status);
      if (view.status === "live") expect(view.stream).toBe(camera);
    });
    await settle();

    expect(views[0]).toBe("connecting");
    expect(views.at(-1)).toBe("live");
    expect(phone.viewOf("live-1").stream).toBe(camera);
  });

  it("asks only the device that shows it", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    phone.watchLive(imageOf(desk), "note-1", () => {});
    await settle();

    const want = sent.find((s) => s.kind === "want");
    expect(want?.to?.device).toBe(desk.liveDeviceId());
  });

  it("turns its camera on for a watcher, and off once they leave", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    const first = new FakeStream();
    desk.adoptSource("live-1", "note-1", "camera", first as never, {
      isOnDemand: true,
    });
    desk.stopCapture("live-1");
    getUserMedia.mockClear();

    const stop = phone.watchLive(imageOf(desk), "note-1", () => {});
    await settle();
    expect(getUserMedia).toHaveBeenCalledTimes(1);
    expect(phone.viewOf("live-1").status).toBe("live");

    const turnedOn = (await getUserMedia.mock.results[0].value) as FakeStream;
    stop();
    await settle();
    expect(turnedOn.tracks[0].stopped).toBe(false);
    await vi.advanceTimersByTimeAsync(20_000);
    expect(turnedOn.tracks[0].stopped).toBe(true);
  });

  it("says a screen isn't shared, and shows it once it is again", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    desk.adoptSource("live-1", "note-1", "screen", new FakeStream() as never);
    desk.stopCapture("live-1");

    phone.watchLive(imageOf(desk, "screen"), "note-1", () => {});
    await settle();
    expect(phone.viewOf("live-1").status).toBe("paused");

    const again = new FakeStream();
    desk.adoptSource("live-1", "note-1", "screen", again as never);
    await settle();
    expect(phone.viewOf("live-1")).toMatchObject({
      status: "live",
      stream: again,
    });
  });

  it("keeps a camera turned off here off, though someone watches", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    const views: string[] = [];
    desk.watchLive(imageOf(desk), "note-1", (view) => views.push(view.status));
    await settle();
    expect(desk.viewOf("live-1").status).toBe("live");

    desk.stopCapture("live-1", { isTurnedOff: true });
    getUserMedia.mockClear();
    expect(desk.viewOf("live-1").status).toBe("needs-share");

    phone.watchLive(imageOf(desk), "note-1", () => {});
    await settle();
    expect(getUserMedia).not.toHaveBeenCalled();
    expect(phone.viewOf("live-1").status).toBe("paused");

    await desk.restartSource(imageOf(desk), "note-1");
    await settle();
    expect(phone.viewOf("live-1").status).toBe("live");
  });

  it("stops a trashed note's live images, and keeps them off once it's back", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    const camera = new FakeStream();
    desk.adoptSource("live-1", "note-1", "camera", camera as never, {
      isOnDemand: true,
    });
    phone.watchLive(imageOf(desk), "note-1", () => {});
    await settle();
    expect(phone.viewOf("live-1").status).toBe("live");

    // What the server sends everyone once the note is in the trash.
    const stop = {
      kind: "stop",
      noteId: "note-1",
      liveId: "*",
      from: { device: "server" },
    };
    for (const hub of hubs) hub.receiveLiveSignal(stop);
    await settle();
    expect(camera.tracks[0].stopped).toBe(true);
    expect(phone.viewOf("live-1").status).toBe("paused");

    // Restored: the phone asks again, and the camera stays off.
    getUserMedia.mockClear();
    await vi.advanceTimersByTimeAsync(6_000);
    await settle();
    expect(getUserMedia).not.toHaveBeenCalled();
    expect(phone.viewOf("live-1").status).toBe("paused");
  });

  it("sends the microphone along, and tells watchers when it's muted", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    const voice = new FakeTrack("audio");
    const stream = new FakeStream([new FakeTrack(), voice]);
    desk.adoptSource("live-1", "note-1", "camera", stream as never, {
      mic: {},
    });
    phone.watchLive(imageOf(desk), "note-1", () => {});
    await settle();
    expect(phone.viewOf("live-1")).toMatchObject({ status: "live", mic: "on" });
    expect(desk.viewOf("live-1").mic).toBe("on");

    desk.setMicMuted("live-1", true);
    await settle();
    expect(voice.enabled).toBe(false);
    expect(phone.viewOf("live-1")).toMatchObject({
      status: "live",
      mic: "muted",
    });

    desk.setMicMuted("live-1", false);
    await settle();
    expect(phone.viewOf("live-1").mic).toBe("on");
  });

  it("turns the microphone on again with the camera, muted as it was", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    const first = new FakeStream([new FakeTrack(), new FakeTrack("audio")]);
    desk.adoptSource("live-1", "note-1", "camera", first as never, {
      mic: {},
      isOnDemand: true,
    });
    desk.setMicMuted("live-1", true);
    desk.stopCapture("live-1");

    phone.watchLive(imageOf(desk), "note-1", () => {});
    await settle();
    expect(phone.viewOf("live-1")).toMatchObject({
      status: "live",
      mic: "muted",
    });
  });

  it("counts the watchers, for the device that shows it and for them", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    const laptop = await newDevice();
    desk.adoptSource("live-1", "note-1", "camera", new FakeStream() as never);
    expect(desk.viewOf("live-1").viewers).toBe(0);

    const stopPhone = phone.watchLive(imageOf(desk), "note-1", () => {});
    await settle();
    expect(desk.viewOf("live-1").viewers).toBe(1);
    expect(phone.viewOf("live-1").viewers).toBe(1);

    laptop.watchLive(imageOf(desk), "note-1", () => {});
    await settle();
    expect(desk.viewOf("live-1").viewers).toBe(2);
    expect(phone.viewOf("live-1").viewers).toBe(2);
    expect(laptop.viewOf("live-1").viewers).toBe(2);

    stopPhone();
    await settle();
    expect(desk.viewOf("live-1").viewers).toBe(1);
    expect(laptop.viewOf("live-1").viewers).toBe(1);
  });

  it("has no sound without a microphone", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    desk.adoptSource("live-1", "note-1", "camera", new FakeStream() as never);
    phone.watchLive(imageOf(desk), "note-1", () => {});
    await settle();
    expect(phone.viewOf("live-1")).toMatchObject({ status: "live", mic: null });
  });

  it("gives nothing for the live image of another note", async () => {
    const desk = await newDevice();
    const phone = await newDevice();
    desk.adoptSource("live-1", "note-1", "camera", new FakeStream() as never);

    phone.watchLive(imageOf(desk), "note-2", () => {});
    await settle();

    expect(sent.some((s) => s.kind === "offer")).toBe(false);
    expect(phone.viewOf("live-1").status).not.toBe("live");
  });

  it("waits for a device that doesn't answer", async () => {
    const phone = await newDevice();
    phone.watchLive(
      { id: "live-1", source: "camera", device: "gone" },
      "note-1",
      () => {},
    );
    await settle();
    await vi.advanceTimersByTimeAsync(8_000);
    expect(phone.viewOf("live-1").status).toBe("waiting");
  });

  it("shows this device's own camera without asking anyone", async () => {
    const desk = await newDevice();
    const views: string[] = [];
    desk.watchLive(imageOf(desk), "note-1", (view) => views.push(view.status));
    await settle();

    expect(getUserMedia).toHaveBeenCalledTimes(1);
    expect(desk.viewOf("live-1")).toMatchObject({
      status: "live",
      isOwn: true,
    });
    expect(views[0]).toBe("starting");
  });
});
