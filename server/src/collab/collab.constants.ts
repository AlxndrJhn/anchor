export const COLLAB_PATH = '/api/collab';

// The text reaches the database this soon after a change, and at the latest
// after this long while people keep typing.
export const COLLAB_SAVE_DELAY_MS = 1000;
export const COLLAB_SAVE_MAX_WAIT_MS = 5000;
export const COLLAB_SAVE_RETRY_MS = 5000;

// How long a session outlives its last client.
export const COLLAB_IDLE_GRACE_MS = 2 * 60 * 1000;

export const COLLAB_JOIN_TIMEOUT_MS = 10 * 1000;
export const COLLAB_PING_INTERVAL_MS = 25 * 1000;
// A JWT is checked when joining; this bounds how long that lasts, as for the
// sync events.
export const COLLAB_MAX_CONNECTION_AGE_MS = 60 * 60 * 1000;

export const MAX_COLLAB_CLIENTS_PER_NOTE = 50;
export const MAX_COLLAB_MESSAGE_BYTES = 5 * 1024 * 1024;
// Well over what typing and a moving caret send.
export const MAX_COLLAB_MESSAGES_PER_WINDOW = 600;
export const COLLAB_RATE_WINDOW_MS = 10 * 1000;

export const COLLAB_CLOSE_GONE = 4404;
export const COLLAB_CLOSE_UNAUTHORIZED = 4401;
export const COLLAB_CLOSE_FULL = 4409;
export const COLLAB_CLOSE_INVALID = 4422;
export const COLLAB_CLOSE_RATE = 4429;
