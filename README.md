# Head Recorder

Screen + webcam, recorded together.

Head Recorder is a native macOS app that records your screen and webcam
at the same time, then composites the camera into a corner bubble
(circle or rectangle, optionally mirrored) over the screen recording —
no separate editing step required.

## Features

- Simultaneous screen + webcam + microphone capture
- Circle or rectangle camera bubble, freely positioned, optionally mirrored
- Automatic start-latency alignment between screen and camera tracks
- Composited export with progress reporting
- Fully sandboxed, built on ScreenCaptureKit

## Requirements

- macOS 15.0 or later

## Building

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to
generate the Xcode project from `project.yml`.

```bash
xcodegen generate
xcodebuild -project HeadRecorder.xcodeproj -scheme HeadRecorder -configuration Debug build
```

## Architecture

Each source (screen, camera) records to its own temporary `.mov` file;
compositing happens after recording stops rather than live, trading a
short export step for a simpler and more robust capture pipeline.
