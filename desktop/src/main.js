// Anchor desktop: a window onto the web client of the user's own Anchor
// server. A built-in page asks for the server once; after that the app opens
// it straight away.

const {
  app,
  BrowserWindow,
  Menu,
  ipcMain,
  net,
  screen,
  shell,
} = require("electron");
const fs = require("node:fs");
const path = require("node:path");
const { pathToFileURL } = require("node:url");

const APP_NAME = "Anchor";
const SETUP_PAGE = path.join(__dirname, "setup.html");
const SETUP_URL = pathToFileURL(SETUP_PAGE).toString();
const HEALTH_TIMEOUT_MS = 10_000;

app.setName(APP_NAME);
if (process.platform === "win32") app.setAppUserModelId("io.github.alxndrjhn.anchor");

// --- Settings (userData/settings.json) -------------------------------------

const settingsFile = () => path.join(app.getPath("userData"), "settings.json");

function readSettings() {
  try {
    const data = JSON.parse(fs.readFileSync(settingsFile(), "utf8"));
    return data && typeof data === "object" ? data : {};
  } catch {
    return {};
  }
}

let settings = {};

function saveSettings() {
  try {
    fs.mkdirSync(path.dirname(settingsFile()), { recursive: true });
    const tmp = `${settingsFile()}.tmp`;
    fs.writeFileSync(tmp, JSON.stringify(settings, null, 2));
    fs.renameSync(tmp, settingsFile());
  } catch (err) {
    console.error("Could not save settings:", err);
  }
}

// --- Server URL ------------------------------------------------------------

/** "notes.example.com/" -> "https://notes.example.com"; null if not a URL. */
function normalizeServerUrl(input) {
  let text = String(input ?? "").trim();
  if (!text) return null;
  if (!/^[a-z][a-z0-9+.-]*:\/\//i.test(text)) text = `https://${text}`;
  let url;
  try {
    url = new URL(text);
  } catch {
    return null;
  }
  if (url.protocol !== "http:" && url.protocol !== "https:") return null;
  url.hash = "";
  url.search = "";
  return url.toString().replace(/\/+$/, "");
}

async function checkServer(serverUrl) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), HEALTH_TIMEOUT_MS);
  try {
    const res = await net.fetch(`${serverUrl}/api/health`, {
      signal: controller.signal,
      cache: "no-store",
      headers: { Accept: "application/json" },
    });
    if (!res.ok) {
      return { ok: false, error: `The server answered ${res.status} ${res.statusText}.` };
    }
    let body;
    try {
      body = await res.json();
    } catch {
      body = null;
    }
    if (!body || body.app !== "anchor") {
      return { ok: false, error: "That address answers, but it is not an Anchor server." };
    }
    return { ok: true, version: typeof body.version === "string" ? body.version : null };
  } catch (err) {
    const reason = controller.signal.aborted ? "it did not answer in time" : err.message;
    return { ok: false, error: `Could not reach the server: ${reason}.` };
  } finally {
    clearTimeout(timer);
  }
}

const serverOrigin = () => {
  try {
    return new URL(settings.serverUrl).origin;
  } catch {
    return null;
  }
};

const originOf = (url) => {
  try {
    return new URL(url).origin;
  } catch {
    return null;
  }
};

function openExternal(url) {
  try {
    const { protocol } = new URL(url);
    if (["http:", "https:", "mailto:"].includes(protocol)) shell.openExternal(url);
  } catch {
    // Not a URL: ignore it.
  }
}

// --- Window ----------------------------------------------------------------

let mainWindow = null;
// What the setup page shows: why it is open, and whether Retry makes sense.
let setupState = { error: null, canRetry: false };

function iconPath() {
  const packaged = path.join(__dirname, "..", "icons", "web-app-manifest-512x512.png");
  if (fs.existsSync(packaged)) return packaged;
  return path.join(__dirname, "..", "..", "web", "public", "web-app-manifest-512x512.png");
}

function visibleBounds(saved) {
  const fallback = { width: 1200, height: 820 };
  if (!saved || !Number.isFinite(saved.width) || !Number.isFinite(saved.height)) return fallback;
  const bounds = {
    width: Math.max(400, Math.round(saved.width)),
    height: Math.max(300, Math.round(saved.height)),
  };
  if (Number.isFinite(saved.x) && Number.isFinite(saved.y)) {
    // Only reuse the position if it is still on a connected screen.
    const area = screen.getDisplayMatching({ ...bounds, x: saved.x, y: saved.y }).workArea;
    const overlaps =
      saved.x < area.x + area.width - 50 &&
      saved.x + bounds.width > area.x + 50 &&
      saved.y < area.y + area.height - 50 &&
      saved.y >= area.y - 50;
    if (overlaps) Object.assign(bounds, { x: Math.round(saved.x), y: Math.round(saved.y) });
  }
  return bounds;
}

function rememberBounds() {
  if (!mainWindow || mainWindow.isDestroyed()) return;
  const maximized = mainWindow.isMaximized();
  const fullScreen = mainWindow.isFullScreen();
  // Keep the normal size, so un-maximizing next time restores it.
  const bounds = maximized || fullScreen ? mainWindow.getNormalBounds() : mainWindow.getBounds();
  settings.window = { ...bounds, maximized };
  saveSettings();
}

function createWindow() {
  const saved = settings.window;
  mainWindow = new BrowserWindow({
    ...visibleBounds(saved),
    minWidth: 400,
    minHeight: 300,
    title: APP_NAME,
    icon: iconPath(),
    show: false,
    backgroundColor: "#232838",
    autoHideMenuBar: process.platform !== "darwin",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      webSecurity: true,
      spellcheck: true,
    },
  });
  if (saved?.maximized) mainWindow.maximize();

  mainWindow.once("ready-to-show", () => mainWindow.show());
  // The window is always "Anchor", whatever the page calls itself.
  mainWindow.on("page-title-updated", (event) => event.preventDefault());

  let saveTimer = null;
  const saveSoon = () => {
    clearTimeout(saveTimer);
    saveTimer = setTimeout(rememberBounds, 500);
  };
  mainWindow.on("resize", saveSoon);
  mainWindow.on("move", saveSoon);
  mainWindow.on("close", () => {
    clearTimeout(saveTimer);
    rememberBounds();
  });
  mainWindow.on("closed", () => {
    mainWindow = null;
  });

  const contents = mainWindow.webContents;

  // A link to another site opens in the system browser. Navigating within
  // the current site stays (so a sign-in provider's own pages work), and
  // server redirects (OIDC sign-in) are not navigations, so they stay too.
  contents.on("will-navigate", (event, url) => {
    if (url === SETUP_URL) return;
    const target = originOf(url);
    if (target && (target === serverOrigin() || target === originOf(contents.getURL()))) return;
    event.preventDefault();
    openExternal(url);
  });

  contents.setWindowOpenHandler(({ url }) => {
    const target = originOf(url);
    if (url.startsWith("blob:") || (target && target === serverOrigin())) {
      return {
        action: "allow",
        overrideBrowserWindowOptions: { icon: iconPath(), autoHideMenuBar: true },
      };
    }
    openExternal(url);
    return { action: "deny" };
  });

  // Loading the server failed (and its service worker could not serve the
  // app offline either): show the setup page with the error and a Retry.
  contents.on("did-fail-load", (_event, code, description, url, isMainFrame) => {
    // -3 is ERR_ABORTED: a navigation that was replaced by another one.
    if (!isMainFrame || code === -3 || url === SETUP_URL) return;
    showSetup({
      error: `Could not open ${settings.serverUrl || url} (${description || `error ${code}`}). Check the connection and that the server is running.`,
      canRetry: Boolean(settings.serverUrl),
    });
  });

  return mainWindow;
}

function showSetup(state = {}) {
  setupState = { error: state.error ?? null, canRetry: Boolean(state.canRetry) };
  mainWindow.loadFile(SETUP_PAGE);
}

function openServer() {
  setupState = { error: null, canRetry: false };
  mainWindow.loadURL(settings.serverUrl);
}

function start() {
  if (settings.serverUrl) openServer();
  else showSetup();
}

// --- Setup page IPC (only the built-in page may use it) --------------------

function fromSetupPage(event) {
  return event.senderFrame?.url === SETUP_URL;
}

ipcMain.handle("anchor:get-state", (event) => {
  if (!fromSetupPage(event)) throw new Error("Not allowed");
  return {
    serverUrl: settings.serverUrl ?? "",
    error: setupState.error,
    canRetry: setupState.canRetry,
    iconUrl: pathToFileURL(iconPath()).toString(),
    version: app.getVersion(),
  };
});

ipcMain.handle("anchor:connect", async (event, input) => {
  if (!fromSetupPage(event)) throw new Error("Not allowed");
  const serverUrl = normalizeServerUrl(input);
  if (!serverUrl) return { ok: false, error: "Enter the address of your server, such as https://notes.example.com." };
  const result = await checkServer(serverUrl);
  if (!result.ok) return result;
  settings.serverUrl = serverUrl;
  saveSettings();
  openServer();
  return { ok: true };
});

ipcMain.handle("anchor:retry", (event) => {
  if (!fromSetupPage(event)) throw new Error("Not allowed");
  if (!settings.serverUrl) return { ok: false };
  openServer();
  return { ok: true };
});

// --- Menu ------------------------------------------------------------------

function changeServer() {
  if (!mainWindow) createWindow();
  mainWindow.show();
  showSetup({ canRetry: Boolean(settings.serverUrl) });
}

function buildMenu() {
  const isMac = process.platform === "darwin";
  const changeServerItem = { label: "Change server…", click: changeServer };
  const template = [
    ...(isMac
      ? [
          {
            label: APP_NAME,
            submenu: [
              { role: "about" },
              { type: "separator" },
              changeServerItem,
              { type: "separator" },
              { role: "services" },
              { type: "separator" },
              { role: "hide" },
              { role: "hideOthers" },
              { role: "unhide" },
              { type: "separator" },
              { role: "quit" },
            ],
          },
        ]
      : [{ label: "&File", submenu: [changeServerItem, { type: "separator" }, { role: "quit" }] }]),
    { role: "editMenu" },
    {
      label: "View",
      submenu: [
        { role: "reload" },
        { role: "forceReload" },
        { role: "toggleDevTools" },
        { type: "separator" },
        { role: "resetZoom" },
        { role: "zoomIn" },
        { role: "zoomOut" },
        { type: "separator" },
        { role: "togglefullscreen" },
      ],
    },
    { role: "windowMenu" },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

// --- App lifecycle ---------------------------------------------------------

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.on("second-instance", () => {
    if (!mainWindow) return;
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
  });

  app.whenReady().then(() => {
    settings = readSettings();
    app.setAboutPanelOptions({ applicationName: APP_NAME, applicationVersion: app.getVersion() });
    buildMenu();
    createWindow();
    start();

    app.on("activate", () => {
      if (!mainWindow) {
        createWindow();
        start();
      }
    });
  });

  app.on("window-all-closed", () => {
    if (process.platform !== "darwin") app.quit();
  });
}

// Never let a page attach webviews or load the app's own preload elsewhere.
app.on("web-contents-created", (_event, contents) => {
  contents.on("will-attach-webview", (event) => event.preventDefault());
});
