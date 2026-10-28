// The built-in setup page gets the whole bridge; the server's web client runs
// as it does in a browser, plus a way to learn of an app update and install it.
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
    connect: (url) => ipcRenderer.invoke("anchor:connect", url),
    retry: () => ipcRenderer.invoke("anchor:retry"),
    ...update,
  });
} else if (window.top === window) {
  contextBridge.exposeInMainWorld("anchorDesktop", update);
}
