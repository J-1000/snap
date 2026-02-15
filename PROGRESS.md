# Snap - Implementation Progress

## Milestone 1: Core Capture — COMPLETE

All 11 implementation steps have been completed and committed. The app builds successfully.

### Commits (oldest → newest)
1. `0dc4a02` scaffold Xcode project with menu bar app configuration
2. `4989405` add menu bar status item with context menu
3. `d047cbb` add global hotkey manager with CGEvent tap
4. `9528134` add full-screen dim overlay windows for all displays
5. `2d66c5d` add click-drag area selection with dimension label
6. `ba2e382` capture selected screen region via ScreenCaptureKit
7. `75a2bba` copy captured screenshot to clipboard as PNG
8. `5df6ca3` add save-to-file with auto-generated filenames
9. `5f5937a` add instant full-screen capture on configurable hotkey
10. `85def59` add preferences window with configurable settings
11. `b8190a3` refine multi-monitor capture and selection spanning

### What's Implemented

| Feature | Status | Notes |
|---|---|---|
| Xcode project (xcodegen) | Done | `project.yml` → `.xcodeproj`, LSUIElement menu bar app |
| Menu bar status item | Done | Camera icon, context menu with all actions |
| Global hotkeys | Done | ⌘⇧⌥4 area capture, ⌘⇧⌥3 full-screen capture (CGEvent tap) |
| Screen overlay | Done | Full-screen dim overlay on all connected displays |
| Area selection | Done | Click-drag rubber-band with dimension label, ESC to cancel |
| Screen capture | Done | ScreenCaptureKit via SCStream (macOS 13+ compatible) |
| Clipboard copy | Done | Auto-copies PNG to clipboard after capture |
| Save to file | Done | `Snap_YYYY-MM-DD_HH-mm-ss.png` to Desktop, Save As dialog |
| Full-screen capture | Done | Instant capture of primary display |
| Preferences window | Done | Save directory, format (PNG/JPEG), quality, retina, auto-save, launch at login |
| Multi-monitor | Done | Per-display overlays, CGDirectDisplayID matching, coordinate mapping |

### File Structure
```
Snap/
├── project.yml
├── Snap/
│   ├── App/
│   │   ├── main.swift              # NSApplication entry point
│   │   ├── AppDelegate.swift       # App lifecycle, wires everything together
│   │   └── StatusBarController.swift   # Menu bar icon + context menu
│   ├── Capture/
│   │   ├── CaptureEngine.swift     # Orchestrates overlay → capture flow
│   │   ├── OverlayWindow.swift     # Full-screen borderless overlay window
│   │   ├── OverlayView.swift       # Mouse tracking, selection rubber-band
│   │   └── ScreenCapture.swift     # ScreenCaptureKit SCStream integration
│   ├── Output/
│   │   ├── OutputManager.swift     # Clipboard copy, save to file, notifications
│   │   └── FileNaming.swift        # Snap_YYYY-MM-DD_HH-mm-ss pattern
│   ├── Preferences/
│   │   ├── PreferencesManager.swift    # UserDefaults wrapper
│   │   └── PreferencesWindow.swift     # Preferences UI (AppKit)
│   ├── HotKey/
│   │   └── HotKeyManager.swift     # Global hotkey via CGEvent tap
│   └── Resources/
│       ├── Info.plist
│       ├── Snap.entitlements
│       └── Assets.xcassets/
```

### Build & Run
```bash
xcodegen generate
xcodebuild -scheme Snap -configuration Debug build
# App is at: ~/Library/Developer/Xcode/DerivedData/Snap-*/Build/Products/Debug/Snap.app
```

### Technical Decisions
- **SCStream instead of SCScreenshotManager**: `SCScreenshotManager` requires macOS 14+. We use `SCStream` with a single-frame capture to maintain macOS 13+ compatibility.
- **CGEvent tap for hotkeys**: No external dependencies. Requires Accessibility permission.
- **Display matching via CGDirectDisplayID**: Reliable matching across identical-resolution multi-monitor setups.
- **No app sandbox**: Required for global hotkey (CGEvent tap) and screen capture.

## Milestone 2: Annotation — IN PROGRESS

### Commits (oldest → newest)
1. `eb8c2d9` add editing toolbar with tool selection and color picker
2. `eb3dba4` add annotation data model and manager
3. `d524a1e` wire rectangle drawing and annotation compositing
4. `1b96288` add start/end point fields to Annotation data model
5. `fe9a40e` add line annotation type and rendering
6. `60fe602` add line tool button to editing toolbar
7. `e82c0cd` wire line drawing interaction in annotation view
8. `a6d7447` add ellipse annotation type and rendering
9. `2cda927` add ellipse tool button to editing toolbar
10. `7bfef61` add ellipse live preview during drag
11. `1b090c1` add arrow annotation type and rendering with arrowhead
12. `de9fdda` add arrow tool button to editing toolbar
13. `1714dc6` wire arrow drawing interaction with live arrowhead preview
14. `06bba36` add freehand annotation type and points field to data model
15. `2b1aaf5` add freehand rendering with round line caps and joins
16. `a50bb19` add freehand tool button to editing toolbar
17. `3fdf7b8` wire freehand drawing interaction with point collection
18. `d706be7` add freehand live preview during drag

### What's Implemented

| Feature | Status | Notes |
|---|---|---|
| Annotation data model | Done | `Annotation` struct with type, rect, startPoint/endPoint, points, color, lineWidth |
| Undo/redo stack | Done | Full state snapshot approach in `AnnotationManager` |
| Annotation compositing | Done | Composites annotations onto CGImage for output |
| Annotation window | Done | Floating borderless window with image canvas + toolbars |
| Action toolbar | Done | Copy (⌘C), Save (⌘S), Save As (⌘⇧S), Close (Esc) |
| Editing toolbar | Done | Tool selection buttons + color well + 4 color presets |
| Rectangle tool | Done | Rect-based drag, outlined stroke |
| Ellipse tool | Done | Rect-based drag, strokeEllipse rendering |
| Line tool | Done | Point-based drag with start/end, live preview |
| Arrow tool | Done | Line + filled triangular arrowhead (30° spread, atan2) |
| Freehand tool | Done | Point-based drag, round caps/joins, live preview |

### Annotation File Structure
```
Snap/Annotation/
├── Annotation.swift         # Data model (AnnotationType enum + Annotation struct)
├── AnnotationManager.swift  # Undo/redo, rendering, compositing
├── AnnotationView.swift     # Canvas view with mouse/key handling
├── AnnotationWindow.swift   # Window layout (canvas + toolbars)
├── EditingToolbar.swift     # Tool buttons + color picker (AnnotationTool enum)
└── ActionToolbar.swift      # Output action buttons (copy/save/close)
```

### Technical Decisions
- **Point-based vs rect-based annotations**: Lines and arrows use startPoint/endPoint fields; rectangles and ellipses use bounding rect. Both stored on `Annotation` struct with optional point fields.
- **Live preview**: Separate drag state (dragOrigin/dragEndPoint/dragRect/dragPoints) drawn without modifying AnnotationManager until mouseUp.
- **Coordinate system**: View coordinates (top-left origin) throughout annotation layer; CGContext flipped when compositing onto bottom-left origin CGImage.
- **Arrowhead rendering**: Filled triangle using atan2 for angle, 30° spread, size scales with lineWidth.
- **Freehand rendering**: Array of CGPoints with `addLine(to:)`, round line caps and joins for smooth appearance.

### Remaining for M2
- [x] Freehand / marker tool (array of points, round caps/joins)
- [ ] Text tool (text input field, font size adjustment)
- [ ] Blur / pixelate tool (Core Image filter on selected region)

## Unit Tests

### Commits (oldest → newest)
1. `1d225bb` add SnapTests unit test target to project configuration
2. `3d8692e` add unit tests for Annotation data model
3. `c2ecc4d` add unit tests for AnnotationManager undo/redo and rendering
4. `fa138c3` add unit tests for FileNaming utility
5. `56ae4bc` add unit tests for OutputManager file saving

### Test Coverage

| Test File | Tests | What's Covered |
|---|---|---|
| `AnnotationTests` | 13 | All 3 initializers (rect, point, freehand), bounding rect computation, unique IDs, default/custom lineWidth, edge cases |
| `AnnotationManagerTests` | 31 | Add, undo, redo, canUndo/canRedo, onChanged callback, rendering all 5 shape types, compositing onto CGImage |
| `FileNamingTests` | 9 | Filename format/regex, default/custom extension, URL points to Desktop |
| `OutputManagerTests` | 6 | Image caching, save to file, PNG round-trip validation, invalid path handling |

### Test File Structure
```
SnapTests/
├── AnnotationTests.swift
├── AnnotationManagerTests.swift
├── FileNamingTests.swift
└── OutputManagerTests.swift
```

### Running Tests
```bash
xcodegen generate
xcodebuild test -scheme SnapTests -configuration Debug -destination 'platform=macOS'
```

### Not Yet Implemented (M3: Polish)
- [ ] JPEG save support (prefs exist, output needs format switching)
- [ ] Print (⌘P)
- [ ] Google reverse image search (⌘G)
- [ ] Retina downscaling
- [ ] Dark mode polish
- [ ] Launch at login
