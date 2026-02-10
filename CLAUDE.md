# Snap - Development Guide

## Project
Native macOS screenshot tool (Swift/AppKit, macOS 13+). See PRD.md for full spec.

## Commit Policy
- Make atomic, frequent commits after each meaningful unit of work
- Each commit should be self-contained and leave the project in a buildable state
- Prefer small, focused commits over large ones

## Build
```
swift build
# or via xcodebuild:
xcodebuild -scheme Snap -configuration Debug build
```

## Architecture
- **CaptureEngine**: Screen overlay, selection interaction, ScreenCaptureKit capture
- **AnnotationEngine**: Drawing tools as CALayer overlays, undo/redo stack
- **OutputManager**: Save (PNG/JPEG), clipboard, print, reverse image search

## Tech Stack
- Swift 5.9+, AppKit, ScreenCaptureKit, Core Image/Core Graphics
- UserDefaults for preferences
- Single .app bundle, no external dependencies
