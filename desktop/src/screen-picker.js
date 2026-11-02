// Sharing a screen or window, for a live image in a note: Electron leaves the
// choice to the app, so this asks in a small window of its own (the system's
// picker instead where there is one, on recent macOS).

const { BrowserWindow, desktopCapturer, ipcMain } = require("electron");
const path = require("node:path");

const PICKER_PAGE = path.join(__dirname, "screen-picker.html");

let pending = null;

function finish(id) {
  if (!pending) return;
  const { window, resolve, sources } = pending;
  pending = null;
  resolve(sources.find((source) => source.id === id) ?? null);
  if (!window.isDestroyed()) window.close();
}

ipcMain.handle("anchor:picker-sources", (event) => {
  if (!pending || event.sender !== pending.window.webContents) return [];
  return pending.sources.map((source) => ({
    id: source.id,
    name: source.name,
    isScreen: source.id.startsWith("screen:"),
    thumbnail: source.thumbnail.isEmpty() ? null : source.thumbnail.toDataURL(),
  }));
});

ipcMain.on("anchor:picker-choose", (event, id) => {
  if (pending && event.sender === pending.window.webContents)
    finish(typeof id === "string" ? id : null);
});

/** The screen or window chosen to share, or null. */
async function pickScreen(parent) {
  finish(null);
  const sources = await desktopCapturer.getSources({
    types: ["screen", "window"],
    thumbnailSize: { width: 320, height: 180 },
  });
  return new Promise((resolve) => {
    const window = new BrowserWindow({
      parent: parent && !parent.isDestroyed() ? parent : undefined,
      modal: !!parent,
      width: 720,
      height: 560,
      minWidth: 420,
      minHeight: 320,
      title: "Share a screen or window",
      autoHideMenuBar: true,
      show: false,
      webPreferences: {
        preload: path.join(__dirname, "screen-picker-preload.js"),
        contextIsolation: true,
        nodeIntegration: false,
        sandbox: true,
      },
    });
    pending = { window, resolve, sources };
    window.once("ready-to-show", () => window.show());
    window.on("closed", () => {
      if (pending?.window === window) finish(null);
    });
    window.loadFile(PICKER_PAGE);
  });
}

/** Lets pages in `session` share a screen or window, once one is chosen. */
function allowScreenSharing(session, getParent) {
  session.setDisplayMediaRequestHandler(
    (_request, callback) => {
      pickScreen(getParent())
        .then((source) => callback(source ? { video: source } : {}))
        .catch(() => callback({}));
    },
    { useSystemPicker: true },
  );
}

module.exports = { allowScreenSharing, pickScreen };
