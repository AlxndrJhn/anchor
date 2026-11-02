// The screen picker's page: a tile per screen and window; a click chooses,
// a double click or Enter shares it.
const picker = window.anchorPicker;
const share = document.getElementById("share");
let chosen = null;

function tile(source) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "tile";
  button.setAttribute("role", "option");
  button.setAttribute("aria-selected", "false");
  button.dataset.id = source.id;
  const frame = document.createElement("span");
  frame.className = "thumb";
  if (source.thumbnail) {
    const img = document.createElement("img");
    img.src = source.thumbnail;
    img.alt = "";
    frame.appendChild(img);
  }
  const name = document.createElement("span");
  name.className = "name";
  name.textContent = source.name;
  button.append(frame, name);
  button.addEventListener("click", () => select(button));
  button.addEventListener("dblclick", () => picker.choose(source.id));
  return button;
}

function select(button) {
  for (const other of document.querySelectorAll(".tile"))
    other.setAttribute("aria-selected", String(other === button));
  chosen = button.dataset.id;
  share.disabled = false;
}

picker.sources().then((sources) => {
  const screens = sources.filter((source) => source.isScreen);
  const windows = sources.filter((source) => !source.isScreen);
  document.getElementById("screens").append(...screens.map(tile));
  document.getElementById("windows").append(...windows.map(tile));
  document.getElementById("windows-title").hidden = !windows.length;
  const first = document.querySelector(".tile");
  if (first) {
    select(first);
    first.focus();
  }
});

share.addEventListener("click", () => chosen && picker.choose(chosen));
document.getElementById("cancel").addEventListener("click", () => picker.choose(null));
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") picker.choose(null);
  else if (event.key === "Enter" && chosen) picker.choose(chosen);
});
