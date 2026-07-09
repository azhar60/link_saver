const DEFAULT_BASE_URL = "http://localhost:3000";

const $input  = document.getElementById("base-url");
const $save   = document.getElementById("save");
const $status = document.getElementById("status");

async function load() {
  const { baseUrl } = await chrome.storage.sync.get({ baseUrl: DEFAULT_BASE_URL });
  $input.value = baseUrl;
}

async function save() {
  const raw = $input.value.trim();
  if (!raw) return;
  try {
    // Normalize: URL constructor validates and strips trailing slash.
    const u = new URL(raw);
    const baseUrl = `${u.protocol}//${u.host}${u.pathname.replace(/\/+$/, "")}`;
    await chrome.storage.sync.set({ baseUrl });
    $input.value = baseUrl;
    $status.classList.add("show");
    setTimeout(() => $status.classList.remove("show"), 1200);
  } catch (_) {
    $input.setCustomValidity("Please enter a valid URL (including https://).");
    $input.reportValidity();
  }
}

$input.addEventListener("input", () => $input.setCustomValidity(""));
$save.addEventListener("click", save);
$input.addEventListener("keydown", (e) => { if (e.key === "Enter") save(); });

load();
