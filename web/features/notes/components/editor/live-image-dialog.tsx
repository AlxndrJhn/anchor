"use client";

import { Camera, Monitor } from "lucide-react";
import * as React from "react";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Field } from "@/components/ui/field";
import { RadioCards } from "@/components/ui/radio-cards";
import { Switch } from "@/components/ui/switch";
import {
  addMicrophone,
  canShowLive,
  listCameras,
  listMicrophones,
  type MicChoice,
  openSource,
} from "../../live-hub";
import type { LiveSource } from "../../live-images";

export interface ChosenSource {
  source: LiveSource;
  stream: MediaStream;
  camera?: string;
  /** Set when the sound of a microphone goes with the video. */
  mic?: MicChoice;
}

const stopAll = (stream: MediaStream | null) => {
  for (const track of stream?.getTracks() ?? []) track.stop();
};

const cameraOf = (stream: MediaStream) =>
  stream.getVideoTracks()[0]?.getSettings().deviceId || undefined;

/**
 * Chooses the camera or screen a live image shows, with a preview of it. The
 * stream is handed over on Add; otherwise it is stopped.
 */
export function LiveImageDialog({
  open,
  onClose,
  onAdd,
}: {
  open: boolean;
  onClose: () => void;
  onAdd: (chosen: ChosenSource) => void;
}) {
  const [source, setSource] = React.useState<LiveSource>("camera");
  const [stream, setStream] = React.useState<MediaStream | null>(null);
  const [cameras, setCameras] = React.useState<MediaDeviceInfo[]>([]);
  const [camera, setCamera] = React.useState<string | undefined>();
  const [error, setError] = React.useState<string | null>(null);
  const [isOpening, setIsOpening] = React.useState(false);
  const [withMic, setWithMic] = React.useState(false);
  const [mics, setMics] = React.useState<MediaDeviceInfo[]>([]);
  const [mic, setMic] = React.useState<string | undefined>();
  const [isAdding, setIsAdding] = React.useState(false);
  const micSwitch = React.useId();
  const preview = React.useRef<HTMLVideoElement>(null);
  const kept = React.useRef<MediaStream | null>(null);
  kept.current = stream;

  React.useEffect(() => {
    if (open) return;
    stopAll(kept.current);
    setStream(null);
    setError(null);
  }, [open]);
  React.useEffect(() => () => stopAll(kept.current), []);

  React.useEffect(() => {
    if (preview.current) preview.current.srcObject = stream;
  }, [stream]);

  const choose = async (next: LiveSource, cameraId?: string) => {
    setSource(next);
    setError(null);
    setIsOpening(true);
    stopAll(kept.current);
    setStream(null);
    try {
      const opened = await openSource(next, cameraId);
      setStream(opened);
      if (next === "camera") {
        setCamera(cameraOf(opened));
        setCameras(await listCameras());
      }
    } catch (e) {
      const refused = e instanceof DOMException && e.name === "NotAllowedError";
      setError(
        next === "screen"
          ? refused
            ? "No screen was chosen, or sharing it wasn’t allowed."
            : "This device can’t share its screen here."
          : refused
            ? "Using the camera wasn’t allowed. Allow it in the browser’s site settings, then try again."
            : "No camera could be turned on.",
      );
    } finally {
      setIsOpening(false);
    }
  };

  const hand = async () => {
    if (!stream) return;
    const choice: MicChoice | undefined = withMic ? { device: mic } : undefined;
    if (choice) {
      setIsAdding(true);
      try {
        await addMicrophone(stream, choice);
      } catch (e) {
        const refused =
          e instanceof DOMException && e.name === "NotAllowedError";
        kept.current = null;
        setStream(null);
        setError(
          refused
            ? "Using the microphone wasn’t allowed. Allow it in the browser’s site settings, or add it without sound."
            : "No microphone could be turned on.",
        );
        return;
      } finally {
        setIsAdding(false);
      }
    }
    const chosen: ChosenSource = {
      source,
      stream,
      camera: source === "camera" ? (camera ?? cameraOf(stream)) : undefined,
      mic: choice,
    };
    // Now the note's; closing mustn't stop it.
    kept.current = null;
    setStream(null);
    onAdd(chosen);
  };

  return (
    <Dialog open={open} onOpenChange={(next) => !next && onClose()}>
      <DialogContent size="lg">
        <DialogHeader>
          <DialogTitle>Add live image</DialogTitle>
          <DialogDescription>
            Shows a camera or screen of this device in the note, live, on every
            device that opens it. The video goes straight between the devices,
            while Anchor is open here.
          </DialogDescription>
        </DialogHeader>
        <DialogBody>
          <RadioCards
            aria-label="What to show"
            value={source}
            onValueChange={(next) => void choose(next)}
            options={[
              {
                value: "camera",
                label: "Camera",
                icon: <Camera />,
                description:
                  "A camera of this device, turned on while someone watches.",
                disabled: !canShowLive("camera"),
              },
              {
                value: "screen",
                label: "Screen or window",
                icon: <Monitor />,
                description: "Shared until you stop it, or close Anchor here.",
                disabled: !canShowLive("screen"),
              },
            ]}
          />
          {source === "camera" && cameras.length > 1 && (
            <Field label="Camera">
              <select
                className="h-9 w-full rounded-md border border-input bg-card px-2 text-ui"
                value={camera ?? ""}
                onChange={(e) => {
                  setCamera(e.target.value);
                  void choose("camera", e.target.value);
                }}
              >
                {cameras.map((c, i) => (
                  <option key={c.deviceId} value={c.deviceId}>
                    {c.label || `Camera ${i + 1}`}
                  </option>
                ))}
              </select>
            </Field>
          )}
          <div className="flex items-center justify-between gap-3">
            <label htmlFor={micSwitch} className="grid gap-0.5">
              <span className="font-semibold text-ui">Microphone</span>
              <span className="text-muted-foreground text-small">
                Sends this device’s sound too; you can mute it while it’s live.
              </span>
            </label>
            <Switch
              id={micSwitch}
              checked={withMic}
              onCheckedChange={(on) => {
                setWithMic(on);
                if (on) void listMicrophones().then(setMics);
              }}
            />
          </div>
          {withMic && mics.length > 1 && (
            <Field label="Which microphone">
              <select
                className="h-9 w-full rounded-md border border-input bg-card px-2 text-ui"
                value={mic ?? ""}
                onChange={(e) => setMic(e.target.value || undefined)}
              >
                <option value="">The usual one</option>
                {mics.map((m, i) => (
                  <option key={m.deviceId} value={m.deviceId}>
                    {m.label || `Microphone ${i + 1}`}
                  </option>
                ))}
              </select>
            </Field>
          )}
          <div className="live-preview">
            {stream ? (
              <video ref={preview} muted autoPlay playsInline />
            ) : (
              <span>
                {error ??
                  (isOpening
                    ? "Opening…"
                    : "Choose the camera or a screen to see it here.")}
              </span>
            )}
          </div>
          {!stream && !isOpening && (
            <Button
              type="button"
              variant="secondary"
              className="justify-self-start"
              onClick={() => void choose(source, camera)}
            >
              {source === "screen" ? "Choose a screen…" : "Turn camera on"}
            </Button>
          )}
        </DialogBody>
        <DialogFooter>
          <Button type="button" variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button
            type="button"
            disabled={!stream || isAdding}
            onClick={() => void hand()}
          >
            Add to note
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
