# Product Requirements Document: Snap

**A Fast, Personal Screenshot Tool for macOS**

| Field | Detail |
|-------|--------|
| Document | Product Requirements Document (PRD) |
| Product name | Snap |
| Version | 1.0 |
| Date | February 2026 |
| Status | Draft |
| Platform | macOS 13 Ventura and later (Intel + Apple Silicon) |

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Goals and Non-Goals](#2-goals-and-non-goals)
3. [Feature Requirements](#3-feature-requirements)
4. [Keyboard Shortcuts Reference](#4-keyboard-shortcuts-reference)
5. [Technical Architecture](#5-technical-architecture)
6. [Non-Functional Requirements](#6-non-functional-requirements)
7. [Development Milestones](#7-development-milestones)
8. [Open Questions and Future Considerations](#8-open-questions-and-future-considerations)

---

## 1. Executive Summary

Snap is a personal-use macOS screenshot utility built for a single power-user workflow: rapid capture, light annotation, and instant save or clipboard copy — used dozens of times per day across coding, design review, bug reporting, and casual communication.

The application provides instant area-selection and full-screen capture, an in-place annotation toolbar with essential drawing and redaction tools, and fast local save or clipboard copy. It is built as a native Swift/AppKit application targeting macOS 13 Ventura and later, supporting both Intel and Apple Silicon processors.

The design philosophy is opinionated minimalism: only the features that get used daily, executed flawlessly, with zero configuration overhead.

---

## 2. Goals and Non-Goals

### 2.1 Goals

- Deliver a native macOS screenshot tool optimized for a single power-user's daily workflow.
- Activation-to-save in under 2 seconds for the common case (capture → clipboard).
- Smooth Retina rendering, dark mode support, and minimal resource consumption.
- Support PNG and JPEG local saves with a configurable default save directory.
- Provide essential annotation tools including blur/pixelate for redacting sensitive content.
- Ship a single self-contained .app bundle with no external runtime dependencies.

### 2.2 Non-Goals

- Video or screen recording.
- Scrolling/long-page capture.
- Automatic window-snap detection.
- iOS or cross-platform support.
- Monetization, analytics, or telemetry of any kind.
- Social media sharing integrations.
- Multi-language / i18n support (English only).
- Built-in cloud upload service (use clipboard + paste into Slack/Discord/etc instead).

---

## 3. Feature Requirements

### 3.1 Screen Capture

#### 3.1.1 Area Selection Capture

When the user presses the activation hotkey, the entire screen dims with a semi-transparent dark overlay. The user clicks and drags to define a rectangular selection. The selected region brightens to preview the capture. A pixel-dimension label (e.g. "1280 × 720") appears at the top-left corner of the selection. The selection handles allow resizing and repositioning before the user commits.

#### 3.1.2 Full-Screen Capture

A separate configurable hotkey triggers an instant full-screen capture. The image is saved directly to the default save location.

#### 3.1.3 Multi-Monitor Support

On activation, all connected displays dim simultaneously. The user can drag a selection that spans multiple monitors. Full-screen capture captures the primary display by default.

---

### 3.2 Annotation Toolbar

After an area selection is confirmed, two toolbars appear adjacent to the selection rectangle.

#### 3.2.1 Editing Toolbar (Right Side)

| # | Tool | Description |
|---|------|-------------|
| 1 | Line | Draws straight lines. Color selectable. Thickness adjustable (1–5 px). |
| 2 | Arrow | Draws directional arrows. Color selectable. Thickness adjustable. |
| 3 | Freehand / Marker | Freeform drawing. Defaults to yellow when used as highlighter. |
| 4 | Rectangle | Draws outlined rectangles. Color selectable. |
| 5 | Ellipse | Draws outlined ellipses. Color selectable. |
| 6 | Text | Adds typed text annotations. Color selectable. Font size adjustable (8–72 pt). |
| 7 | Blur / Pixelate | Applies a pixelation or Gaussian blur to a selected rectangular region. Essential for redacting passwords, tokens, emails, and PII in screenshots. |
| 8 | Color Picker | Preset swatches plus a custom color dialog. |
| 9 | Undo / Redo | ⌘Z undoes the most recent annotation. ⌘⇧Z redoes. Supports full undo/redo stack. |
| 10 | Close (X) | Discards the capture and returns to normal desktop. |

#### 3.2.2 Action Toolbar (Bottom)

| # | Action | Shortcut | Description |
|---|--------|----------|-------------|
| 1 | Copy to Clipboard | ⌘C | Copies the annotated screenshot to the system clipboard. |
| 2 | Save to File | ⌘S | Saves to the default directory (or opens a save dialog with ⌘⇧S). |
| 3 | Google Image Search | ⌘G | Performs a reverse image search via Google Images. |
| 4 | Print | ⌘P | Opens the macOS system print dialog. |

---

### 3.3 Saving and Output

#### 3.3.1 Local Save

Pressing ⌘S saves the annotated screenshot to the default save directory (`~/Desktop` by default, configurable in preferences). Pressing ⌘⇧S opens a save-as dialog for choosing a different location or format. Supported formats are PNG (default) and JPEG (with configurable quality). The file name is auto-generated using the pattern `Snap_YYYY-MM-DD_HH-mm-ss`.

#### 3.3.2 Clipboard Copy

Pressing ⌘C copies the annotated image to the macOS pasteboard in PNG format.

---

### 3.4 Reverse Image Search

Pressing ⌘G uploads the capture to Google's reverse image search endpoint and opens the results page in the default browser.

---

### 3.5 Print

The print action (⌘P) opens the macOS system print dialog with the current annotated screenshot pre-loaded.

---

### 3.6 Preferences

The preferences window is accessible from the menu bar icon's context menu. It is a single flat pane with the following settings:

- **Activation hotkey** (default: ⌘⇧⌥4). Supports Fn/Ctrl/Shift/Option/⌘ combos.
- **Full-screen capture hotkey** (configurable).
- **Default save directory** (folder picker, default: `~/Desktop`).
- **Default save format**: PNG or JPEG. JPEG quality slider (50–100).
- **Retina downscaling toggle**: when enabled, saves at 1x resolution for smaller files.
- **Include mouse cursor** in captures (toggle, default: off).
- **Show notification** after save/copy (toggle, default: on).
- **Launch at login** (toggle, default: on).

---

## 4. Keyboard Shortcuts Reference

| Action | Default Shortcut |
|--------|------------------|
| Activate / start capture | ⌘⇧⌥4 (configurable) |
| Instant full-screen save | Configurable |
| Copy to clipboard | ⌘C |
| Save to default directory | ⌘S |
| Save as (choose location) | ⌘⇧S |
| Google reverse image search | ⌘G |
| Print | ⌘P |
| Undo annotation | ⌘Z |
| Redo annotation | ⌘⇧Z |
| Cancel / close capture | Esc |

---

## 5. Technical Architecture

### 5.1 Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Language | Swift 5.9+ | Native performance, first-class macOS API access |
| UI framework | AppKit (NSWindow, NSView) | Full control over overlay windows and screen capture |
| Screen capture | ScreenCaptureKit (macOS 13+) | Apple's modern, permission-aware capture API |
| Image processing | Core Image / Core Graphics | Hardware-accelerated annotation and blur rendering |
| Persistence | UserDefaults | Sufficient for the small number of preferences |
| Packaging | Native .app bundle | No Electron, no runtime dependencies |

### 5.2 Application Architecture

The application follows a modular architecture with three core subsystems:

- **CaptureEngine:** Manages screen dimming overlay, user selection interaction, and pixel capture via ScreenCaptureKit. Handles multi-monitor geometry and Retina scaling.
- **AnnotationEngine:** Renders annotation tools (line, arrow, freehand, rectangle, ellipse, text, blur) as lightweight CALayer overlays on the captured image. Maintains a full undo/redo stack.
- **OutputManager:** Handles save-to-file (PNG/JPEG conversion), clipboard copy, print dispatch, and reverse image search. Generates filenames from the timestamp pattern.

### 5.3 macOS Permissions

The app requires Screen Recording permission (Privacy & Security → Screen Recording). On first launch, the app requests this entitlement. If denied, a clear instructional dialog explains how to grant the permission. The app handles macOS Sonoma/Sequoia periodic re-authorization prompts gracefully by detecting capture failures and re-prompting with guidance.

### 5.4 System Requirements

- macOS 13 Ventura or later (for ScreenCaptureKit v2).
- 64-bit Intel or Apple Silicon (M1/M2/M3/M4) processor.
- Approximately 15 MB disk space for the application bundle.
- Internet connection required only for Google reverse image search.

---

## 6. Non-Functional Requirements

### 6.1 Performance

- Activation-to-overlay latency: < 150 ms from hotkey press to screen dimming.
- Annotation rendering: 60 fps during freehand drawing on Retina displays.
- Save-to-file: < 500 ms for a 4K resolution PNG.
- Idle memory footprint: < 20 MB when running as a background process.
- CPU usage while idle: < 0.1%.

### 6.2 Reliability

- The app must never crash during capture, even if the target window is closed mid-selection.
- All user preferences must persist across app restarts and macOS updates.

### 6.3 Privacy

- No telemetry, analytics, or usage tracking of any kind.
- No data is transmitted except explicit user-initiated actions (reverse image search).
- All data stays local on disk.

### 6.4 macOS Integration

- Respects system appearance (light/dark mode) and accent color.
- Menu bar icon with context menu for preferences and quit.

---

## 7. Development Milestones

| Milestone | Scope | Target |
|-----------|-------|--------|
| **M1 – Core Capture** | Area selection, full-screen capture, multi-monitor support, clipboard copy, save-to-PNG. Menu bar icon with activation hotkey. Preferences pane. | Week 1–2 |
| **M2 – Annotation** | All annotation tools: line, arrow, freehand, rectangle, ellipse, text (with size), blur/pixelate, color picker, undo/redo. | Week 3–4 |
| **M3 – Polish** | JPEG save support, print, Google reverse image search, Retina downscaling, dark mode, launch-at-login, final testing and bug fixes. | Week 5–6 |

---

## 8. Future Considerations (Post v1.0)

- Window-snap capture: automatically detect window boundaries on hover.
- Scrolling capture: capture content beyond the visible viewport.
- Timed / delayed capture with countdown overlay.
- OCR text extraction from captured regions.
- Video / GIF recording of a selected screen region.
- Numbered step annotations for tutorial-style screenshots.
- Cloud upload to S3-compatible bucket with shareable links (if clipboard-paste workflow proves insufficient).
