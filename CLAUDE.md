# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

ScreenCamRecorder is a macOS SwiftUI app (deployment target macOS 13.0) that records the screen and the
webcam simultaneously, then composites the camera into a corner bubble (circle or rectangle) over the
screen recording — similar in spirit to Screen Studio. UI strings and code comments are in Ukrainian.

## Build / run

The Xcode project is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) —
regenerate it after adding/removing files or changing build settings:

```bash
xcodegen generate
```

Build and run (no CocoaPods/SPM dependencies beyond system frameworks):

```bash
open ScreenCamRecorder.xcodeproj   # then Cmd+R in Xcode
# or headless:
xcodebuild -project ScreenCamRecorder.xcodeproj -scheme ScreenCamRecorder -configuration Debug build
```

There is no test target in this project yet.

Code signing uses automatic signing with `DEVELOPMENT_TEAM: M2BF9ZE9NW` (set in `project.yml`) and hardened
runtime is enabled — required for Screen Recording / Camera entitlements to actually work when running a
built `.app` (not just via `Cmd+R` from Xcode with an ad-hoc signature).

## Architecture

The app follows a **capture-separately, composite-afterward** (post-processing) pipeline, not a live
compositing pipeline. This tradeoff is deliberate (see `PLAN.md`, Етап 5) — it's simpler and more robust
than compositing frames in real time, at the cost of an export step after recording stops.

- **`ContentView`** owns three `@StateObject`s — `RecordingSettings`, `ScreenRecorder`, `CameraRecorder` —
  and drives the whole lifecycle from `toggleRecording()`.
- **Start**: `ScreenRecorder.start()` and `CameraRecorder.start(deviceID:)` are kicked off together via
  `async let` so both capture sessions begin as close to simultaneously as possible. There is still no
  shared `CMClock` between them, but each recorder now stamps `startHostTime` (`ProcessInfo.systemUptime`)
  the moment its *first actual frame* arrives — `ScreenRecorder` in `handle(_:)`, `CameraRecorder` via the
  `AVCaptureFileOutputRecordingDelegate.fileOutput(_:didStartRecordingTo:from:)` callback. `Compositor`
  compares the two timestamps and trims the leading edge of whichever stream started first before
  inserting both into the composition, so the two tracks line up at the same real-world moment instead of
  both naively starting at composition time zero. This corrects the one-time start-latency offset (e.g.
  `SCShareableContent`/`SCStream.startCapture()` setup taking longer than `AVCaptureSession.startRunning()`)
  but does **not** correct for clock-rate drift accumulating over a long recording — if that becomes an
  issue, this is the place to look next.
- **`ScreenRecorder`** wraps `ScreenCaptureKit` (`SCStream` + `SCStreamOutput`) and writes frames directly
  to an `AVAssetWriter` `.mov` in the temp directory. It filters `SCStreamFrameInfo` for `.complete` status
  before appending — partial/idle frames are dropped in `handle(_:)`. Screen Recording permission is *not*
  declared in `Info.plist`; macOS prompts for it automatically on the first `SCShareableContent` call, and
  the user must approve it in System Settings → Privacy & Security → Screen Recording.
- **`CameraRecorder`** wraps `AVCaptureSession` + `AVCaptureMovieFileOutput`, recording to a separate temp
  `.mov`. It also captures the default microphone as a second audio input when mic permission is granted
  (mic denial does not block video recording). Camera device list is populated via
  `AVCaptureDevice.DiscoverySession` in `refreshAvailableCameras()`; the device type list intentionally
  excludes `.external` (only available on macOS 14+, and deployment target is 13.0).
- **`Compositor.combine(screenURL:cameraURL:settings:)`** (Stage 5) builds an `AVMutableComposition` from
  the two temp files, then uses a **custom `AVVideoCompositing`** (`OverlayCompositor` +
  `OverlayInstruction`, both private to `Compositor.swift`) to render every frame: the screen track as
  background, the camera track scaled/cropped/masked (circle uses a `CIFilter.radialGradient` blend mask;
  rectangle is a plain scaled overlay) and positioned per corner from `RecordingSettings`, composited with
  Core Image (`CIContext.render`). Export runs through `AVAssetExportSession` at
  `AVAssetExportPresetHighestQuality`, writing the final `.mov` to `~/Movies`.
- **`RecordingSettings`** (`@MainActor` `ObservableObject`) is the single source of truth for camera
  device ID, overlay corner (`OverlayPosition`), overlay size fraction, and overlay shape — read by both
  `ContentView` (for the picker/slider UI) and `Compositor` (for render parameters).

## Entitlements / sandboxing

The app is sandboxed (`com.apple.security.app-sandbox`) with camera, audio-input, user-selected
read/write, and movies read/write entitlements declared in `ScreenCamRecorder.entitlements`. Screen
Recording has no corresponding sandbox entitlement key — it's governed purely by the TCC prompt triggered
by ScreenCaptureKit at runtime.

## Development stages

`PLAN.md` (Ukrainian) lays out the original 7-stage MVP plan; `README.md` documents how to import the
Swift skeleton into a fresh Xcode project. Commit history follows these stages directly (e.g. "Implement
CameraRecorder (Stage 3)", "Implement Compositor (Stage 5)") — check `git log` for what's implemented vs.
still a stub when picking up new work.
