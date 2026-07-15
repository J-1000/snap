# Snap — Implementation Progress

Last verified: 2026-07-15

## Status

All three planned milestones are implemented. The app builds on macOS 13+ with
Swift 5.9, complete Swift concurrency checking, and Hardened Runtime enabled for
distribution signing.

| Milestone | Status | Delivered |
|---|---|---|
| M1 — Core capture | Complete | Area/full-screen capture, per-display overlays, selection editing, clipboard and file output, preferences |
| M2 — Annotation | Complete | Eight annotation tools, style controls, native-resolution compositing, undo/redo, Retina-aware editor |
| M3 — Polish | Complete | JPEG, print, reverse-search handoff, share sheet, OCR, delayed capture, permission recovery, launch at login |

## Current capabilities

### Capture

- Fixed global shortcuts: ⌘⇧⌥4 for area capture and ⌘⇧⌥3 for full screen.
- Area selections can be drawn, moved, resized, nudged, and constrained to a
  square. All displays receive an overlay; capture is performed on the display
  where the selection starts.
- Full-screen, five-second delayed, and on-device OCR capture modes.
- Screen Recording and Accessibility permission prompting and recovery.
- ScreenCaptureKit one-shot capture on macOS 14+, with a timeout-protected
  stream fallback on macOS 13.
- Display-native color-space capture and optional cursor inclusion.

### Annotation

- Line, arrow, freehand, rectangle, ellipse, text, pixelate, and numbered step
  badge tools.
- Color, stroke-width, and font-size controls remembered between captures.
- Shift-constrained geometry, delete-last, and full undo/redo.
- Native-resolution output with point-correct Retina text. Oversized captures
  zoom to fit so both toolbars remain reachable.

### Output and preferences

- PNG/JPEG saves, configurable JPEG quality and save directory, Save As, and
  optional 1× Retina downscaling.
- PNG and TIFF clipboard representations.
- Native print and share sheets; reverse image search copies the image and opens
  Google Images for the user to paste.
- Optional automatic copy/save, editor opening, notifications, cursor capture,
  and launch at login.
- A post-capture HUD keeps Copy, Save, and Annotate reachable by default.

## Quality gates

The test suite currently contains 100 tests covering annotation data and
pixel-level rendering, undo/redo, output encoding/downscaling, preferences,
capture-state serialization, editor sizing, selection geometry, filename
generation, and hotkey matching.

```bash
xcodegen generate
xcodebuild -scheme Snap -configuration Debug clean build
xcodebuild analyze -scheme Snap -configuration Debug -destination 'platform=macOS'
xcodebuild test -scheme SnapTests -configuration Debug -destination 'platform=macOS'
```

The latest verification completed successfully in this workspace. Xcode 26
emits toolchain-only notices for App Intents metadata (the app does not use App
Intents) and for its XCTest libraries targeting macOS 14 while the application
continues to target macOS 13.
