// Only the built-in setup page gets this bridge; the server's web client runs
// as it does in a browser.
const { contextBridge, ipcRenderer } = require("electron");

if (location.protocol === "file:") {
  contextBridge.exposeInMainWorld("anchorDesktop", {
    getState: () => ipcRenderer.invoke("anchor:get-state"),
    connect: (url) => ipcRenderer.invoke("anchor:connect", url),
    retry: () => ipcRenderer.invoke("anchor:retry"),
  });
}
