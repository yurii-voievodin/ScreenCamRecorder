# CLAUDE.md

## Project

macOS SwiftUI app (deployment target 13.0) that records screen + webcam
simultaneously, then composites the camera into a corner bubble (circle/
rectangle, optionally mirrored) over the screen recording. UI strings and
code comments are in Ukrainian.

## Build / run

Project is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen).
The `ScreenCamRecorder` target uses Xcode 16 synced folders, so new/moved/
deleted Swift files need no project change. Regenerate only when build
settings, targets, or excludes change:

```bash
xcodegen generate
```

```bash
xcodebuild -project ScreenCamRecorder.xcodeproj -scheme ScreenCamRecorder -configuration Debug build
```

## Architecture

Capture-separately, composite-afterward: each source records to its own
temp `.mov`; compositing happens after recording stops, not live. Simpler
and more robust, at the cost of an export step.

Screen and camera capture start together but share no clock — each stamps
a start timestamp on its first real frame, and the compositor trims the
leading edge of whichever stream started first so tracks align. This
corrects one-time start latency, not clock-rate drift over long
recordings.

Screen Recording permission isn't declared in `Info.plist` — macOS prompts
for it automatically at runtime via ScreenCaptureKit.

## Entitlements

Sandboxed with camera, audio-input, user-selected and movies read/write
entitlements. Screen Recording has no entitlement key — it's a runtime TCC
prompt triggered by ScreenCaptureKit.
