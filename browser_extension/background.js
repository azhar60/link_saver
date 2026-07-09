const DEFAULT_BASE_URL = "http://localhost:3000";

async function getBaseUrl() {
  const { baseUrl } = await chrome.storage.sync.get({ baseUrl: DEFAULT_BASE_URL });
  return (baseUrl || DEFAULT_BASE_URL).replace(/\/+$/, "");
}

function isSaveable(tab) {
  if (!tab?.url) return false;
  // Chrome-internal and extension pages can't be sensibly saved.
  return /^https?:\/\//i.test(tab.url);
}

async function saveTab(tab) {
  if (!isSaveable(tab)) {
    await chrome.action.setBadgeBackgroundColor({ color: "#ef4444" });
    await chrome.action.setBadgeText({ text: "!" });
    setTimeout(() => chrome.action.setBadgeText({ text: "" }), 1500);
    return;
  }
  try {
    const base = await getBaseUrl();
    const url = new URL(`${base}/links/new`);
    url.searchParams.set("link[url]", tab.url);
    if (tab.title) url.searchParams.set("link[title]", tab.title);
    await chrome.tabs.create({ url: url.toString(), active: true });
  } catch (err) {
    console.error("[Link Saver] Failed to open new-link tab:", err);
    await chrome.action.setBadgeBackgroundColor({ color: "#ef4444" });
    await chrome.action.setBadgeText({ text: "!" });
    setTimeout(() => chrome.action.setBadgeText({ text: "" }), 1500);
  }
}

chrome.action.onClicked.addListener(async (tab) => { await saveTab(tab); });

// Optional keyboard shortcut (bind in chrome://extensions/shortcuts).
chrome.commands?.onCommand.addListener(async (command) => {
  if (command !== "save-current-tab") return;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (tab) await saveTab(tab);
});
