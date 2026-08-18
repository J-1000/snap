# Snap

A fast, native macOS screenshot tool built for power users. Area, window, full-screen, and scrolling capture; editable annotation; local history; and instant output — all in a lightweight menu bar app.

## Features

### Capture
- **Area selection** — click and drag to select a region, adjust with handles (with crosshair/resize cursors), arrow-key nudge, Shift to square, then press Return to capture
- **Window capture** — choose an on-screen window, with configurable shadow and transparent/white/black background
- **Full-screen capture** — instant capture of the primary/menu-bar display via global hotkey
- **Delayed capture** — full-screen capture after a 5-second countdown for hover states and transient menus
- **Repeat last area** — recapture the previous region, clamped safely if the display layout changed
- **Scrolling capture** — select a scrollable region and stitch overlapping frames into one long image
- **Text capture (OCR)** — select a region to recognize its text on-device (Vision) and copy it to the clipboard
- **QR capture** — select a QR code and copy its decoded payload locally with Vision
- **Multi-monitor support** — overlays all displays for per-display region selection
- **Wide-gamut** — captures in the display's native (Display P3) color
- **Optional HDR** — HDR screenshot capture on supported Apple-silicon Macs running macOS 26; SDR remains the default
- **Post-capture HUD** — a draggable thumbnail with Annotate / Copy / Save / Pin so the editor and output actions are always reachable

### Annotation
- **Rectangle / Ellipse** — outlined stroke, color selectable, Shift for a square/circle
- **Line / Arrow** — adjustable thickness, filled arrowhead, Shift snaps to 45°
- **Freehand / Marker** — freeform drawing with smooth strokes
- **Text** — click to place, inline editing, Enter to commit, Escape to cancel
- **Blur / Pixelate** — drag to select region, applies pixelation to obscure content
- **Solid Redaction** — exports a fully opaque black rectangle for passwords, tokens, and other sensitive content
- **Step badges** — click to drop auto-incrementing numbered circles for tutorials
- **Color picker** — preset swatches plus custom color dialog
- **Editable annotations** — select, move, resize, recolor, duplicate, delete, and reorder existing markup
- **Canvas controls** — zoom, trackpad/scrollbar pan, and non-destructive crop
- **Annotation controls** — adjustable stroke width and text size, remembered between captures
- **Undo / Redo / Delete** — visible controls plus the full ⌘Z / ⌘⇧Z history stack
- The editor opens at the capture location, crisp on Retina

### Output
- **Copy to clipboard** (⌘C) — copies as PNG and TIFF, with optional retina downscale
- **Save to file** (⌘S) — auto-generated `Snap_YYYY-MM-DD_HH-mm-ss` filenames in your configured directory and format
- **Save as** (⌘⇧S) — choose location and format
- **Share** — native share sheet (AirDrop, Messages, Mail, Markup, …)
- **Print** (⌘P) — print the annotated screenshot
- **Reverse image search** (⌘G) — copies the image and opens Google Images
- **Pin screenshot** — keep one or more resizable screenshot references floating above normal windows across Spaces
- **Private local history** — opt-in (off by default), stores at most 20 PNG captures locally, with copy/save/pin/delete and permanent clear controls
- **Configurable preferences** — global shortcuts with conflict detection, save directory, PNG/JPEG/HEIC, JPEG quality, auto-save, clipboard, editor behavior, cursor capture, notifications, history, and launch at login

## Requirements

- macOS 13 Ventura or later
- Screen Recording permission
- Accessibility permission (for global hotkeys)

Snap deliberately retains macOS 13 support for Intel and older-Mac distribution. The macOS 13 streaming capture fallback and cursor compatibility path are therefore kept; macOS 15+ uses the public frame-resize cursor API.

## Build

```bash
xcodegen generate
xcodebuild -project Snap.xcodeproj -scheme Snap -configuration Debug build
```

Development uses Xcode 26.6, Swift 6, and XcodeGen 2.46 or later.

The app bundle is output to `~/Library/Developer/Xcode/DerivedData/Snap-*/Build/Products/Debug/Snap.app`.

## Default Shortcuts

| Action | Shortcut |
|--------|----------|
| Area capture | ⌘⇧⌥4 (customizable) |
| Full-screen capture | ⌘⇧⌥3 (customizable) |
| Copy to clipboard | ⌘C |
| Save to file | ⌘S |
| Save as | ⌘⇧S |
| Reverse image search | ⌘G |
| Print | ⌘P |
| Undo / Redo | ⌘Z / ⌘⇧Z |
| Duplicate / reorder selected annotation | ⌘D / ⌘[ / ⌘] |
| Delete selected or last annotation | ⌫ |
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
├── Output/               # Clipboard, file save, history, OCR/QR
├── Preferences/          # Settings UI and UserDefaults persistence
├── HotKey/               # Global hotkey via CGEvent tap
└── Resources/            # Info.plist, entitlements, assets
SnapTests/                # Permission-free unit and rendering tests
SnapUITests/              # Accessibility/UI smoke tests
```

## Progress

| Milestone | Status |
|-----------|--------|
| **M1 — Core Capture** | Complete |
| **M2 — Annotation** | Complete |
| **M3 — Polish** | Complete — output actions, OCR/QR, permission UX, wide-gamut capture, Retina editor, accessibility, and performance polish |
| **Power-user expansion** | Complete — window/scrolling capture, editable markup, crop/zoom, pinning, repeat area, shortcuts, HDR/HEIC, redaction, and private history |

## Testing

```bash
xcodegen generate
xcodebuild test -scheme Snap -configuration Debug -destination 'platform=macOS'
```

The suite contains 137 tests: 133 permission-free unit/integration tests and four UI smoke tests covering Preferences, both editor toolbars, the capture HUD, and the VoiceOver capture overlay. The shared scheme records production coverage; current Snap line coverage is 43.23% (up from 21.13%), and CI enforces a 40% floor on GitHub's macOS 26 / Xcode 26.6 runner.

## Tech Stack

Swift 6, AppKit, ScreenCaptureKit, Vision, Core Image/Core Graphics. Single `.app` bundle with no external runtime dependencies.

## License

Private — not licensed for redistribution.
