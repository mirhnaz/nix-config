# macOS application manifest

A checklist of GUI apps currently in `/Applications`, so a new machine doesn't
silently end up missing something. There is **no API to auto-restore
hand-downloaded apps** — this is a curated list, not an installer.

Regenerate the raw classification any time with:

```sh
for app in /Applications/*.app; do
  name=$(basename "$app")
  if [ -e "$app/Contents/_MASReceipt/receipt" ]; then src="appstore";
  else src="manual"; fi
  printf '%-10s %s\n' "$src" "$name"
done
```

Snapshot taken: 2026-05-31. You have **0 Homebrew casks** today — everything
below was installed manually or from the App Store. The goal over time is to
**migrate as many as possible into `./Brewfile`** (the "Candidate cask" column),
shrinking the manual list. Verify each cask name first: `brew search <name>`.

---

## 1. Migrate these to `./Brewfile` (Homebrew cask available)

Once added to the Brewfile, these reinstall automatically via `brew bundle install`
and drop off the manual list. Add as `cask "<name>"`.

| App | Candidate cask | Done? |
|---|---|---|
| 1Password | `1password` | ☐ |
| Charles | `charles` | ☐ |
| ChatGPT | `chatgpt` | ☐ |
| Claude | `claude` | ☐ |
| Fantastical | `fantastical` | ☐ |
| Firefox | `firefox` | ☐ |
| Ghostty | `ghostty` | ☑ (in Brewfile) |
| Google Chrome | `google-chrome` | ☐ |
| Logi Options+ (`logioptionsplus`) | `logi-options-plus` | ☐ |
| Maccy | `maccy` | ☐ |
| Moonlight | `moonlight` | ☐ |
| NordVPN | `nordvpn` | ☐ |
| Obsidian | `obsidian` | ☐ |
| Ollama | `ollama` | ☐ |
| OneDrive | `onedrive` | ☐ |
| Tor Browser | `tor-browser` | ☐ |
| Visual Studio Code | `visual-studio-code` | ☐ |
| Zoom (`zoom.us`) | `zoom` | ☐ |

> Note: Microsoft Office apps (Word, Excel, PowerPoint, OneNote, Outlook, Teams)
> are typically deployed/updated by your employer's MDM (see section 3). The
> `microsoft-office` cask exists but may conflict with managed installs — check
> with IT before brew-managing them.

## 2. App Store apps (reinstall from the App Store)

Detected via `_MASReceipt`. Sign in to the App Store and reinstall, or use
`mas` (`brew "mas"` + `mas install <id>`) to script it.

- GarageBand (Apple)
- iMovie (Apple)
- Keynote Creator Studio
- LocalSend
- Numbers Creator Studio
- Pages Creator Studio
- Tailscale
- WhatsApp
- Xcode (Apple — or via `xcode-select` / Xcode Command Line Tools)

## 3. Work / enterprise-managed (do NOT install manually)

These are pushed by your organization's MDM. On a new work machine they arrive
via enrollment — don't hunt for download links.

- Duo Desktop
- Microsoft Defender Shim
- Microsoft Excel / OneNote / Outlook / PowerPoint / Teams / Word
- Trellix Endpoint Security for Mac
- TrellixSystemExtensions

## 4. Apple system apps (no action)

- Safari (ships with macOS)

## 5. Pure manual downloads (fill in source URL)

Anything that is genuinely a website download with no cask and no App Store
entry. Record the URL so reinstall is one click. (Currently empty — everything
above is categorized; move items here if a cask candidate turns out not to exist.)

| App | Download URL | Notes |
|---|---|---|
| _example_ | https://… | |
