# Snap

A fast, native macOS screenshot tool built for power users. Area selection, full-screen capture, multi-monitor support, and annotation — all in a lightweight menu bar app.

## Features

### Capture
- **Area selection** — click and drag to select a region, adjust with handles (with crosshair/resize cursors), arrow-key nudge, Shift to square, then press Return to capture
- **Full-screen capture** — instant capture via global hotkey
- **Delayed capture** — full-screen capture after a 5-second countdown for hover states and transient menus
- **Text capture (OCR)** — select a region to recognize its text on-device (Vision) and copy it to the clipboard
- **Multi-monitor support** — overlays all displays for per-display region selection
- **Wide-gamut** — captures in the display's native (Display P3) color
- **Post-capture HUD** — a thumbnail with Annotate / Copy / Save so the editor is always reachable

### Annotation
- **Rectangle / Ellipse** — outlined stroke, color selectable, Shift for a square/circle
- **Line / Arrow** — adjustable thickness, filled arrowhead, Shift snaps to 45°
- **Freehand / Marker** — freeform drawing with smooth strokes
- **Text** — click to place, inline editing, Enter to commit, Escape to cancel
- **Blur / Pixelate** — drag to select region, applies pixelation to obscure content
- **Step badges** — click to drop auto-incrementing numbered circles for tutorials
- **Color picker** — preset swatches plus custom color dialog
- **Annotation controls** — adjustable stroke width and text size, remembered between captures
- **Undo / Redo / Delete** — full undo/redo stack (⌘Z / ⌘⇧Z); delete removes the last annotation
- The editor opens at the capture location, crisp on Retina

### Output
- **Copy to clipboard** (⌘C) — copies as PNG and TIFF, with optional retina downscale
- **Save to file** (⌘S) — auto-generated `Snap_YYYY-MM-DD_HH-mm-ss` filenames in your configured directory and format
- **Save as** (⌘⇧S) — choose location and format
- **Share** — native share sheet (AirDrop, Messages, Mail, Markup, …)
- **Print** (⌘P) — print the annotated screenshot
- **Reverse image search** (⌘G) — copies the image and opens Google Images
- **Configurable preferences** — save directory, format (PNG/JPEG), JPEG quality, auto-save, clipboard, editor behavior, cursor capture, notifications, launch at login

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
| Reverse image search | ⌘G |
| Print | ⌘P |
| Undo / Redo | ⌘Z / ⌘⇧Z |
| Delete last annotation | ⌫ |
| Nudge selection | ← ↑ → ↓ (⇧ for 10px) |
| Constrain to square / 45° | Hold ⇧ while dragging |
| Cancel | Esc |
| Confirm area selection | Return |

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
| **M2 — Annotation** | Complete |
| **M3 — Polish** | Complete — print, reverse image search, share sheet, OCR/delayed capture, permission UX, wide-gamut capture, Retina editor, and performance/output polish |

## Testing

```bash
xcodegen generate
xcodebuild test -scheme Snap -configuration Debug -destination 'platform=macOS'
```

104 unit tests covering the Annotation data model (including text and blur), AnnotationManager (undo/redo, rendering, pixel-level compositing), FileNaming, OutputManager, capture serialization and editor sizing, SelectionGeometry (selection/resize math), HotKeyManager modifier matching, and PreferencesManager round-trips.

## Tech Stack

Swift 5.9+, AppKit, ScreenCaptureKit, Core Image/Core Graphics. Single `.app` bundle with no external dependencies.

## License

Private — not licensed for redistribution.
