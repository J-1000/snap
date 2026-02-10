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

## 6. Technical Architecture

### 6.1 Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| Language | Swift 5.9+ | Native performance, first-class macOS API access |
| UI framework | AppKit (NSWindow, NSView) | Full control over overlay windows and screen capture |
| Screen capture | ScreenCaptureKit (macOS 13+) | Apple's modern, permission-aware capture API |
| Image processing | Core Image / Core Graphics | Hardware-accelerated annotation rendering |
| Networking | URLSession + async/await | Native HTTP with retry logic |
| Storage | SQLite via GRDB.swift | Lightweight local gallery database |
| Cloud storage | S3-compatible API | Self-hosted or cloud bucket for uploads |
| Packaging | Native .app bundle | No Electron, no runtime dependencies |

### 6.2 Application Architecture

The application follows a modular architecture with five core subsystems:

- **CaptureEngine:** Manages screen dimming overlay, user selection interaction, and pixel capture via ScreenCaptureKit. Handles multi-monitor geometry and Retina scaling.
- **AnnotationEngine:** Renders annotation tools (line, arrow, freehand, rectangle, text) as lightweight CALayer overlays on the captured image. Maintains an undo stack of annotation operations.
- **OutputManager:** Handles save-to-file (with format conversion), clipboard copy, print dispatch, and cloud upload (with retry). Generates filenames from the configurable pattern.
- **CloudService:** Abstracts the upload target (S3 bucket or custom endpoint). Generates short URLs, manages authentication, and handles link expiration metadata.
- **GalleryStore:** SQLite-backed storage for screenshot metadata, thumbnails, and gallery UI data source.

### 6.3 macOS Permissions

The app requires Screen Recording permission (Privacy & Security → Screen Recording). On first launch, the app programmatically requests this entitlement. If denied, the app displays a clear instructional dialog explaining how to grant the permission. The app handles the macOS Sonoma/Sequoia periodic re-authorization prompts gracefully by detecting capture failures and re-prompting the user with guidance.

### 6.4 System Requirements

- macOS 13 Ventura or later (for ScreenCaptureKit v2).
- 64-bit Intel or Apple Silicon (M1/M2/M3/M4) processor.
- Approximately 25 MB disk space for the application bundle.
- 512 MB RAM minimum.
- Internet connection required only for cloud upload and reverse image search features.

---

## 7. Non-Functional Requirements

### 7.1 Performance

- Activation-to-overlay latency: < 150 ms from hotkey press to screen dimming.
- Annotation rendering: 60 fps during freehand drawing on Retina displays.
- Save-to-file: < 500 ms for a 4K resolution PNG.
- Cloud upload: < 3 seconds for a typical 1080p screenshot on a 10 Mbps connection.
- Idle memory footprint: < 30 MB when running as a background process.
- CPU usage while idle: < 0.1%.

### 7.2 Reliability

- Cloud uploads must succeed on ≥ 99% of attempts (with retry logic), compared to Lightshot's reported ~50% Mac failure rate.
- The app must never crash during capture, even if the target window is closed mid-selection.
- All user preferences must persist across app restarts and macOS updates.

### 7.3 Privacy and Security

- No telemetry, analytics, or usage tracking of any kind.
- All uploaded screenshots use 128-bit random URL tokens (not sequential IDs).
- Local gallery database is stored in the app's sandboxed container.
- No data is transmitted except explicit user-initiated uploads.

### 7.4 Accessibility

- All toolbar buttons include accessibility labels for VoiceOver.
- Keyboard-only operation is supported for all core workflows.
- Respects macOS system appearance (light/dark mode) and accent colour.

---

## 8. Lightshot Feature Parity Checklist

The following table maps every documented Lightshot for Mac feature to its Snap equivalent, noting where the implementation matches, improves upon, or intentionally departs from the reference.

| Lightshot Feature | Snap Status | Notes |
|-------------------|------------------|-------|
| Area selection capture | ✅ Match | Identical drag-to-select with dimension readout |
| Full-screen capture | ✅ Match | Configurable hotkey |
| Multi-monitor capture | ✅ Match | Spans all displays; stitch option for full-screen |
| Cursor capture toggle | ✅ Match | In General settings |
| Line tool | ✅ Match | Color selectable |
| Arrow tool | ✅ Match | Color selectable |
| Freehand / marker | ✅ Match | Yellow default for highlighter mode |
| Rectangle tool | ✅ Match | Color selectable |
| Text tool | ⬆️ Improved | Adjustable font size (8–72 pt) vs. fixed size |
| Color picker (RGB/HSL) | ✅ Match | Presets + custom color dialog |
| Undo (multiple) | ✅ Match | ⌘Z stack |
| Close / discard | ✅ Match | Esc or X button |
| Save to file (PNG) | ⬆️ Improved | PNG + JPEG + WebP; configurable save directory |
| Copy to clipboard | ✅ Match | Plus quick-copy via ⌘+drag |
| Cloud upload + short URL | ⬆️ Improved | Self-hosted; retry logic; link expiration |
| Share to Facebook | ✅ Match | Opens browser |
| Share to Twitter/X | ✅ Match | Opens browser |
| Share to Pinterest | ✅ Match | Opens browser |
| Share to VKontakte | ✅ Match | Opens browser |
| Share via email | ✅ Match | Attaches to default mail client |
| Google reverse image search | ✅ Match | Opens browser with results |
| TinEye reverse image search | ✅ Match | Opens browser with results |
| Print | ✅ Match | macOS system print dialog |
| Online editor (Pixlr) | ✅ Match | Opens in default browser |
| Configurable hotkeys | ✅ Match | Fn/Ctrl/Shift/Option/⌘ combos |
| Upload format selection | ✅ Match | PNG or JPEG with quality slider |
| Retina downscaling | ✅ Match | Toggle in Output settings |
| Proxy settings | ✅ Match | None / system / manual |
| Language selector (24+) | ✅ Match | In General settings |
| Auto-copy link after upload | ✅ Match | Toggle in General settings |
| Menu bar + Dock icon | ✅ Match | Native macOS integration |
| Screenshot gallery | ⬆️ Improved | Local SQLite vs. web-only prntscr.com |
| Dark mode support | ✅ Match | System appearance respected |
| Launch at login | ⬆️ Improved | Native toggle in settings |
| Default save directory | 🆕 Added | Not available in Lightshot Mac |
| JPEG/WebP local save | 🆕 Added | Lightshot Mac is PNG-only for local saves |
| Link expiration | 🆕 Added | Not available in Lightshot |
| Upload retry logic | 🆕 Added | Fixes Lightshot's ~50% Mac upload failures |

---

## 9. Development Milestones

| Milestone | Scope | Target |
|-----------|-------|--------|
| **M1 – Core Capture** | Area selection, full-screen capture, multi-monitor, clipboard copy, basic save-to-PNG. Menu bar icon with activation hotkey. | Week 1–3 |
| **M2 – Annotation** | All 7 annotation tools (line, arrow, freehand, rectangle, text with size slider, color picker, undo). Print. | Week 4–6 |
| **M3 – Cloud + Sharing** | Cloud upload with retry, short URL generation, social sharing (Facebook, Twitter/X, Pinterest, VK, email), reverse image search (Google + TinEye), online editor integration. | Week 7–9 |
| **M4 – Polish + Gallery** | Full settings panel (all 5 tabs), local screenshot gallery with search, JPEG/WebP save support, filename patterns, dark mode, accessibility, launch-at-login, final testing. | Week 10–12 |

---

## 10. Open Questions and Future Considerations

### 10.1 Open Questions

1. Should the cloud backend be a self-hosted server (e.g. a simple Cloudflare Worker + R2 bucket) or a full third-party service? A self-hosted approach maximizes privacy but requires maintenance.
2. Should the app be distributed via the Mac App Store (sandboxed, with review delays) or as a direct download (more flexibility, requires notarization only)?
3. Is VKontakte sharing still relevant for personal use, or should it be replaced with a more useful target (e.g. Slack webhook, Discord webhook)?

### 10.2 Future Considerations (Post v1.0)

- Window-snap capture: automatically detect window boundaries on hover.
- Scrolling capture: capture content beyond the visible viewport.
- Timed / delayed capture with countdown overlay.
- OCR text extraction from captured regions.
- Video / GIF recording of a selected screen region.
- Blur / pixelate annotation tool for redacting sensitive information.
- Numbered step annotations for tutorial-style screenshots.
