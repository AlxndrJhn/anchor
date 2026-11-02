// The built-in "Welcome to Anchor+" page: on the first start (with the choice
// of no server), from "Connect to a server…", or when the server can't open.
(async () => {
  const api = window.anchorDesktop;
  const form = document.getElementById("form");
  const input = document.getElementById("url");
  const connect = document.getElementById("connect");
  const retry = document.getElementById("retry");
  const local = document.getElementById("local");
  const errorBox = document.getElementById("error");

  const showError = (message) => {
    errorBox.textContent = message || "";
    errorBox.hidden = !message;
  };

  const busy = (on, label) => {
    connect.disabled = on;
    retry.disabled = on;
    local.disabled = on;
    input.disabled = on;
    connect.textContent = on ? label : "Continue";
  };

  const state = await api.getState();
  document.getElementById("version").textContent = `Anchor+ desktop ${state.version}`;
  input.value = state.serverUrl;
  showError(state.error);
  retry.hidden = !state.canRetry;
  local.hidden = !state.hasServer && !state.isFirstStart;
  // Opened from "Change server…" rather than after an error.
  if (!state.error) retry.textContent = "Back to your notes";
  input.focus();
  input.select();

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    showError(null);
    busy(true, "Connecting…");
    try {
      const result = await api.connect(input.value);
      if (!result.ok) {
        showError(result.error);
        busy(false);
        input.focus();
      }
    } catch (err) {
      showError(String(err?.message || err));
      busy(false);
    }
  });

  const update = document.getElementById("update");
  api.onUpdate(({ version }) => {
    update.title = `Restart Anchor+ to update to ${version}`;
    update.hidden = false;
  });
  update.addEventListener("click", () => {
    update.disabled = true;
    update.textContent = "Restarting…";
    api.installUpdate().then((started) => {
      if (started) return;
      update.disabled = false;
      update.textContent = "Update";
    });
  });

  local.addEventListener("click", async () => {
    showError(null);
    busy(true, "Continue");
    await api.useLocal();
  });

  retry.addEventListener("click", async () => {
    showError(null);
    busy(true, "Continue");
    retry.textContent = "Connecting…";
    await api.retry();
  });
})();
