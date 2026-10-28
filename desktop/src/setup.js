// The built-in "Connect to your server" page.
(async () => {
  const api = window.anchorDesktop;
  const form = document.getElementById("form");
  const input = document.getElementById("url");
  const connect = document.getElementById("connect");
  const retry = document.getElementById("retry");
  const errorBox = document.getElementById("error");

  const showError = (message) => {
    errorBox.textContent = message || "";
    errorBox.hidden = !message;
  };

  const busy = (on, label) => {
    connect.disabled = on;
    retry.disabled = on;
    input.disabled = on;
    connect.textContent = on ? label : "Connect";
  };

  const state = await api.getState();
  document.getElementById("logo").src = state.iconUrl;
  document.getElementById("version").textContent = `Anchor desktop ${state.version}`;
  input.value = state.serverUrl;
  showError(state.error);
  retry.hidden = !state.canRetry;
  // Opened from "Change server…" rather than after an error.
  if (!state.error) retry.textContent = "Back to your notes";
  input.focus();
  input.select();

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    showError(null);
    busy(true, "Checking…");
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
    update.title = `Restart Anchor to update to ${version}`;
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

  retry.addEventListener("click", async () => {
    showError(null);
    busy(true, "Connect");
    retry.textContent = "Connecting…";
    await api.retry();
  });
})();
