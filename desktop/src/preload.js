// The built-in setup page gets the whole bridge; the web client (the server's
// or the built-in one) runs as it does in a browser, plus a way to learn of an
// app update and install it, and to take in the notes kept without a server.
const { contextBridge, ipcRenderer } = require("electron");

const update = {
  /** Calls back with { version } once an update is ready; returns an unsubscribe. */
  onUpdate(callback) {
    const listener = (_event, ready) => callback(ready);
    ipcRenderer.on("anchor:update", listener);
    ipcRenderer
      .invoke("anchor:get-update")
      .then((ready) => ready && callback(ready))
      .catch(() => {});
    return () => ipcRenderer.removeListener("anchor:update", listener);
  },
  /** Quits, installs the update and starts the new version. */
  installUpdate: () => ipcRenderer.invoke("anchor:install-update"),
};

if (location.protocol === "file:") {
  contextBridge.exposeInMainWorld("anchorDesktop", {
    getState: () => ipcRenderer.invoke("anchor:get-state"),
    connect: (url, headers) => ipcRenderer.invoke("anchor:connect", url, headers),
    retry: () => ipcRenderer.invoke("anchor:retry"),
    useLocal: () => ipcRenderer.invoke("anchor:use-local"),
    ...update,
  });
} else if (window.top === window) {
  contextBridge.exposeInMainWorld("anchorDesktop", {
    ...update,
    /** The notes kept without a server, as an Anchor backup, or null. */
    takeLocalNotes: () => ipcRenderer.invoke("anchor:take-local-notes"),
    /** They are in the account: the built-in client lets them go. */
    localNotesMoved: () => ipcRenderer.invoke("anchor:local-notes-moved"),
  });
}
