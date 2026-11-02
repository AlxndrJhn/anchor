// The screen picker's page gets only what it needs to choose.
const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("anchorPicker", {
  /** [{ id, name, isScreen, thumbnail }] */
  sources: () => ipcRenderer.invoke("anchor:picker-sources"),
  /** The chosen source's id, or null to share nothing. */
  choose: (id) => ipcRenderer.send("anchor:picker-choose", id),
});
