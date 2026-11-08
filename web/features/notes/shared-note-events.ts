// The server closes with this when the note's link was turned off.
const linkGoneCloseCode = 4404;
const minRetryDelayMs = 1_000;
const maxRetryDelayMs = 60_000;

export interface SharedNoteEventsOptions {
  /** The note changed, or the link did: load it again. */
  onChange: () => void;
  /** Whether the socket is open; while it isn't, the page polls. */
  onConnectedChange: (connected: boolean) => void;
  createSocket?: (url: string) => WebSocket;
  random?: () => number;
  location?: Pick<Location, "protocol" | "host">;
}

export interface SharedNoteEventStream {
  close: () => void;
}

export const sharedNoteEventsUrl = (
  token: string,
  location: Pick<Location, "protocol" | "host">,
) =>
  `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}` +
  `/api/shared/${encodeURIComponent(token)}/events`;

/**
 * Keeps a WebSocket open on a note's share link, which says whenever the note
 * changes. It carries no content: the page loads the note through the link.
 */
export function connectSharedNoteEvents(
  token: string,
  options: SharedNoteEventsOptions,
): SharedNoteEventStream {
  const {
    onChange,
    onConnectedChange,
    createSocket = (url) => new WebSocket(url),
    random = Math.random,
    location = window.location,
  } = options;
  const url = sharedNoteEventsUrl(token, location);

  let closed = false;
  let attempt = 0;
  let socket: WebSocket | null = null;
  let retry: ReturnType<typeof setTimeout> | undefined;

  const nextDelay = () => {
    const backoff = Math.min(minRetryDelayMs * 2 ** attempt, maxRetryDelayMs);
    attempt = Math.min(attempt + 1, 6);
    // ±25% jitter, so pages don't all come back at once after a restart.
    return Math.round(backoff * (0.75 + random() * 0.5));
  };

  const open = () => {
    if (closed) return;
    const ws = createSocket(url);
    socket = ws;
    ws.onopen = () => {
      attempt = 0;
      onConnectedChange(true);
      // Whatever changed while it was connecting or away.
      onChange();
    };
    ws.onmessage = () => onChange();
    ws.onclose = (event) => {
      if (socket !== ws) return;
      socket = null;
      onConnectedChange(false);
      if (closed) return;
      if (event.code === linkGoneCloseCode) {
        onChange();
        return;
      }
      retry = setTimeout(open, nextDelay());
    };
  };

  open();

  return {
    close() {
      closed = true;
      clearTimeout(retry);
      const ws = socket;
      socket = null;
      ws?.close();
    },
  };
}
