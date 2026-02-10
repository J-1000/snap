# Snap

A fast, native macOS screenshot tool built for power users. Area selection, full-screen capture, multi-monitor support, and annotation — all in a lightweight menu bar app.

## Features

- **Area selection capture** — click and drag to select any region, with live dimension labels
- **Full-screen capture** — instant capture via configurable hotkey
- **Multi-monitor support** — overlays all displays, selections can span monitors
- **Annotation tools** — lines, arrows, shapes, text, freehand drawing, and blur/pixelate for redaction
- **Fast output** — copy to clipboard (⌘C), save to file (⌘S), print (⌘P), or reverse image search (⌘G)
- **Configurable preferences** — save directory, format (PNG/JPEG), hotkeys, and more

## Requirements

- macOS 13 Ventura or later
- Screen Recording permission

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

## Tech Stack

Swift 5.9+, AppKit, ScreenCaptureKit, Core Image/Core Graphics. Single `.app` bundle with no external dependencies.

## License

Private — not licensed for redistribution.
