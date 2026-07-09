# Link Saver — Browser Extension

A tiny Chrome/Edge/Brave extension. One click on the toolbar (or `Cmd+Shift+L` / `Ctrl+Shift+L`) opens the New-link page in your Link Saver instance with the current tab's URL and title pre-filled.

## Install (unpacked, developer mode)

1. Open `chrome://extensions` (or `edge://extensions`, `brave://extensions`).
2. Toggle **Developer mode** on (top right).
3. Click **Load unpacked** and select the `browser_extension/` folder in this repo.
4. Pin the "Link Saver" icon to your toolbar.

## Configure

Right-click the extension icon → **Options** (or click "Details" → "Extension options"). Set the **App URL** to wherever your Link Saver is running:

- Local dev: `http://localhost:3000`
- Deployed: `https://your-domain.example`

The default is `http://localhost:3000`.

## Keyboard shortcut

The default binding is `Cmd+Shift+L` on macOS, `Ctrl+Shift+L` on Windows/Linux. To rebind: open `chrome://extensions/shortcuts` and find "Link Saver".

## What it does

Clicking the toolbar icon opens:

```
<APP_URL>/links/new?link[url]=<current-tab-url>&link[title]=<current-tab-title>
```

The Rails app's `LinksController#new` reads those params via strong params (`link_params.permit(:url, :title)`) and pre-fills the form. Same code path as the drag-to-bookmarks bookmarklet at `/bookmarklet`.

## Files

- `manifest.json` — Manifest V3 declaration
- `background.js` — service worker; handles toolbar click + keyboard shortcut
- `options.html` / `options.js` — settings page (App URL)
- `icons/` — 16/32/48/128 PNGs generated from `icon.svg`

## Permissions

- `storage` — remembers your App URL preference
- `tabs` — reads the active tab's URL and title on click; opens the new-link page in a new tab
- No `host_permissions` — the extension doesn't read page content
