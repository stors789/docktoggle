<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/arch-arm64%20%7C%20x86__64-brightgreen" alt="Architecture">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/built%20by-DeepSeek%20v4%20Pro%20%2B%20OpenCode-purple" alt="Built by">
  <br>
  <a href="README_CN.md"><img src="https://img.shields.io/badge/readme-%E4%B8%AD%E6%96%87%20%7C%20Chinese-red?style=flat-square" alt="中文文档"></a>
</p>

<p align="center">
  <img src="icon.png" width="128" alt="DockToggle Icon">
</p>

# DockToggle

Turn your Dock into a toggle switch. Click a running app's icon to focus it &mdash; click it again to **hide** or **minimize**.

<p align="center">
  <i>"Click once to focus, twice to dismiss."</i>
</p>

---

## How It Works

```
         ┌────────────────────────────────────┐
         │  CGEvent Tap (system-wide hook)    │
         │         mouseDown event            │
         └──────────────┬─────────────────────┘
                        │
                        ▼
              ┌─────────────────┐
              │  Click in Dock?  │──── No ──▶ Pass through
              └────────┬────────┘
                       │ Yes
                       ▼
              ┌─────────────────┐
              │  Target PID =    │──── No ──▶ Pass through
              │  Frontmost PID?  │
              └────────┬────────┘
                       │ Yes
                       ▼
              ┌─────────────────┐
              │  Swallow click   │
              │  Hide / Minimize │
              └─────────────────┘
```

DockToggle installs a `CGEvent` tap that intercepts left mouse clicks. When you click inside the Dock area on an already-frontmost app's icon, the click is swallowed and your chosen action (hide or minimize) is executed instead.

### Two Modes

| Mode | Behavior |
|---|---|
| **Hide** | Hides the entire application (`Cmd+H` equivalent) |
| **Minimize** | Minimizes the frontmost window (`Cmd+M` equivalent) |

---

## Installation

### For Users

```bash
# 1. Clone
git clone https://github.com/stors789/docktoggle.git
cd docktoggle

# 2. Build (requires Xcode Command Line Tools)
./build.sh

# 3. Move to Applications (important for permissions)
mv .build/DockToggle.app /Applications/

# 4. Launch
open /Applications/DockToggle.app
```

**First launch:** Right-click the app and select *Open* to bypass Gatekeeper, or run:

```bash
xattr -cr /Applications/DockToggle.app
```

Then grant the two permissions in **System Settings → Privacy & Security**.

### Requirements

| Item | Details |
|---|---|
| macOS | 14.0 (Sonoma) or later |
| Architecture | Apple Silicon &amp; Intel (auto-detected) |
| Build Tools | Xcode Command Line Tools (`xcode-select --install`) |

---

## Permissions

DockToggle needs two permissions — both must be granted for the app to work.

| Permission | Why It's Needed |
|---|---|
| **Accessibility** | Read the Dock's UI hierarchy (icon positions, app identities), and perform window minimize/restore |
| **Input Monitoring** | Intercept mouse clicks globally to detect Dock icon interactions |

### Setup Steps

1. Launch DockToggle — it will show a red "Permissions Needed" badge
2. Go to **System Settings → Privacy & Security → Accessibility**, toggle DockToggle **ON**
3. Go to **System Settings → Privacy & Security → Input Monitoring**, toggle DockToggle **ON**
4. Quit and reopen DockToggle — the status dot should turn green

> **Troubleshooting:** If it still doesn't work after granting both, remove DockToggle from both lists, quit the app, then re-add and re-launch.

---

## Project Structure

```
Sources/
├── DockToggleApp.swift              # @main entry, menubar UI, lifecycle
├── DebugLog.swift                   # File-based logging to /tmp/docktoggle.log
├── SettingsView.swift               # Settings window content
├── SettingsWindowManager.swift      # NSWindow management
├── Engine/
│   ├── EventTapEngine.swift         # Core: CGEvent tap + click interception
│   ├── ActionExecutor.swift         # Hide / minimize via AppKit + AX APIs
│   ├── DockInspector.swift          # Dock process resolution, frame detection
│   ├── DockIconCache.swift          # Icon position/PID cache (1s refresh)
│   └── FrontmostTracker.swift       # Tracks active frontmost app PID
├── Models/
│   └── BehaviorMode.swift           # .hide | .minimize enum
├── Permissions/
│   └── PermissionsManager.swift     # Permission check + request logic
└── Settings/
    ├── ConfigStore.swift            # @AppStorage persistence
    └── PermissionsGateView.swift    # Permission status UI
```

Built as a single Swift executable bundled into a `.app` — no Xcode project, no SPM, no third-party dependencies.

---

## Debugging

Logs are written to `/tmp/docktoggle.log`. You can tail them live:

```bash
tail -f /tmp/docktoggle.log
```

Or view recent entries from the Settings window within the app.

---

## License

MIT

---

<p align="center">
  <sub>Entirely generated by <b>DeepSeek v4 Pro</b> + <b>OpenCode</b></sub>
</p>
