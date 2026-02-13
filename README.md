# Snap

A fast, native macOS screenshot tool built for power users. Area selection, full-screen capture, multi-monitor support, and annotation — all in a lightweight menu bar app.

## Features

### Capture
- **Area selection** — click and drag to select any region, with live dimension labels
- **Full-screen capture** — instant capture via configurable hotkey
- **Multi-monitor support** — overlays all displays, selections can span monitors

### Annotation
- **Rectangle** — outlined stroke, color selectable
- **Ellipse** — outlined stroke, color selectable
- **Line** — straight lines with adjustable thickness
- **Arrow** — directional arrows with filled arrowhead
- **Color picker** — preset swatches plus custom color dialog
- **Undo / Redo** — full undo/redo stack (⌘Z / ⌘⇧Z)

### Output
- **Copy to clipboard** (⌘C) — PNG format
- **Save to file** (⌘S) — auto-generated `Snap_YYYY-MM-DD_HH-mm-ss` filenames
- **Save as** (⌘⇧S) — choose location and format
- **Configurable preferences** — save directory, format (PNG/JPEG), hotkeys, and more

## Requirements

- macOS 13 Ventura or later
- Screen Recording permission
- Accessibility permission (for global hotkeys)

## Build

```bash
xcodegen generate
xcodebuild -scheme Snap -configuration Debug build
```

The app bundle is output to `~/Library/Developer/Xcode/DerivedData/Snap-*/Build/Products/Debug/Snap.app`.

## Default Shortcuts

| Action | Shortcut |
|--------|----------|
| Area capture | ⌘⇧⌥4 |
| Full-screen capture | ⌘⇧⌥3 |
| Copy to clipboard | ⌘C |
| Save to file | ⌘S |
| Save as | ⌘⇧S |
| Undo / Redo | ⌘Z / ⌘⇧Z |
| Cancel | Esc |

## Project Structure

```
Snap/
├── App/                  # Entry point, app delegate, menu bar
├── Capture/              # Overlay windows, selection, ScreenCaptureKit
├── Annotation/           # Drawing tools, canvas, toolbars, undo/redo
├── Output/               # Clipboard, file save, filename generation
├── Preferences/          # Settings UI and UserDefaults persistence
├── HotKey/               # Global hotkey via CGEvent tap
└── Resources/            # Info.plist, entitlements, assets
```

## Progress

| Milestone | Status |
|-----------|--------|
| **M1 — Core Capture** | Complete |
| **M2 — Annotation** | In progress — rectangle, ellipse, line, arrow done; freehand, text, blur remaining |
| **M3 — Polish** | Not started — JPEG output, print, reverse image search, dark mode polish |

See [PROGRESS.md](PROGRESS.md) for detailed implementation notes.

## Tech Stack

Swift 5.9+, AppKit, ScreenCaptureKit, Core Image/Core Graphics. Single `.app` bundle with no external dependencies.

## License

Private — not licensed for redistribution.
