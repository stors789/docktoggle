# DockToggle

A macOS utility that turns your Dock into a toggle — click a running app's icon to focus it, click again to **hide** or **minimize** it.

## Features

- **Hide Mode**: Clicking an already-frontmost app's Dock icon hides the entire application.
- **Minimize Mode**: Clicking an already-frontmost app's Dock icon minimizes its frontmost window.
- Lives in the menubar; no Dock icon (`LSUIElement`).
- Toggle behavior from the menubar popover or settings window.
- Optional launch at login via `SMAppService`.
- Real-time engine status indicator and debug log viewer.

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (arm64)
- Xcode Command Line Tools (for building)
- **Accessibility** permission (to inspect Dock UI and manipulate windows)
- **Input Monitoring** permission (to intercept mouse clicks)

## Build

```bash
./build.sh
```

The built app will be at `.build/DockToggle.app`. Move it to `/Applications` and launch it. Grant the requested permissions when prompted.

## How It Works

1. An `CGEvent` tap intercepts left mouse clicks system-wide.
2. On mouse-down, it checks if the click is inside the Dock area.
3. If the clicked icon belongs to the currently frontmost app, it swallows the click and performs the selected action (hide or minimize).
4. Otherwise, it lets macOS handle the click normally and applies a 400ms debounce to prevent accidental retriggering.

## Permissions

DockToggle requires two permissions to function:

| Permission | Why |
|---|---|
| **Accessibility** | Inspect Dock icon positions, identify which app an icon belongs to, and perform minimize/restore actions on windows |
| **Input Monitoring** | Intercept mouse click events globally via CoreGraphics event tap |

Grant these in **System Settings → Privacy & Security** after first launch.

## Project Structure

```
Sources/
├── DockToggleApp.swift              # App entry point, menubar UI, lifecycle
├── DebugLog.swift                   # File-based debug logging
├── SettingsView.swift               # Settings window UI
├── SettingsWindowManager.swift      # Settings NSWindow manager
├── Engine/
│   ├── EventTapEngine.swift         # Core: CGEvent tap, click interception
│   ├── DecisionEngine.swift         # Legacy decision logic (unused)
│   ├── ActionExecutor.swift         # Hide/minimize via AppKit + Accessibility
│   ├── DockInspector.swift          # Dock process resolution, frame detection
│   ├── DockIconCache.swift          # Dock icon position/PID cache (1s refresh)
│   └── FrontmostTracker.swift       # Frontmost app PID tracker
├── Models/
│   └── BehaviorMode.swift           # Hide vs Minimize enum
├── Permissions/
│   └── PermissionsManager.swift     # Permission checks and requests
└── Settings/
    ├── ConfigStore.swift            # UserDefaults persistence
    └── PermissionsGateView.swift    # Permission status UI
```

## Debug Logs

Debug logs are written to `/tmp/docktoggle.log`. You can view the last 30 lines from the Settings window.
