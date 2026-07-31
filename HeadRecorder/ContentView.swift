import SwiftUI
import AppKit
import ScreenCaptureKit

struct ContentView: View {
    @StateObject private var settings = RecordingSettings()
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var cameraRecorder = CameraRecorder()

    @State private var isRecording = false
    @State private var isTransitioning = false
    @State private var statusText = String(localized: .readyToRecord)
    @State private var lastRecordingURL: URL?
    @State private var previewWindowController: CameraPreviewWindowController?
    @State private var currentEdgeInsets = OverlayEdgeInsets.zero
    @State private var cameraSelectionTask: Task<Void, Never>?
    @State private var microphoneSelectionTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 14) {
            StatusRow(isRecording: isRecording, statusText: statusText, lastRecordingURL: lastRecordingURL)

            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    SourceRow(icon: "display", help: String(localized: .display)) {
                        Picker(selection: $settings.selectedDisplayID) {
                            if screenRecorder.availableDisplays.isEmpty {
                                Text(.noDisplay).tag(CGDirectDisplayID(0))
                            }
                            ForEach(screenRecorder.availableDisplays, id: \.displayID) { display in
                                Text(displayName(for: display)).tag(display.displayID)
                            }
                        } label: {
                            Text(.display)
                        }
                        .disabled(isRecording)
                    }

                    Divider()

                    SourceRow(icon: "video.fill", help: String(localized: .camera)) {
                        HStack(spacing: 8) {
                            Picker(selection: $settings.selectedCameraID) {
                                if cameraRecorder.availableCameras.isEmpty {
                                    Text(.noCamera).tag("")
                                }
                                ForEach(cameraRecorder.availableCameras, id: \.uniqueID) { device in
                                    Text(device.localizedName).tag(device.uniqueID)
                                }
                            } label: {
                                Text(.camera)
                            }
                            .disabled(isRecording)

                            Toggle(isOn: $settings.isCameraMirrored) {
                                Image(systemName: "flip.horizontal")
                            }
                            .toggleStyle(.button)
                            .disabled(isRecording)
                            .help(Text(.mirrorCamera))
                        }
                    }

                    Divider()

                    SourceRow(icon: "mic.fill", help: String(localized: .microphone)) {
                        Picker(selection: $settings.selectedMicrophoneID) {
                            Text(.systemMicrophone).tag("")
                            ForEach(cameraRecorder.availableMicrophones, id: \.uniqueID) { device in
                                Text(device.localizedName).tag(device.uniqueID)
                            }
                            Text(.noAudio).tag(RecordingSettings.noMicrophoneID)
                        } label: {
                            Text(.microphone)
                        }
                        .disabled(isRecording)
                    }
                }
            }

            CardView {
                HStack(alignment: .center, spacing: 18) {
                    CornerPositionPicker(selection: $settings.overlayPosition, isEnabled: !isRecording)

                    VStack(spacing: 10) {
                        Picker(selection: $settings.overlayShape) {
                            ForEach(OverlayShape.allCases, id: \.self) { shape in
                                Image(systemName: shape.iconName).tag(shape)
                            }
                        } label: {
                            Text(.shape)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .disabled(isRecording)
                        .help(Text(.cameraOverlayShape))

                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.overlaySize, in: 0.1...0.4)
                            Text(settings.overlaySize, format: .percent.precision(.fractionLength(0)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 34, alignment: .trailing)
                        }
                        .disabled(isRecording)
                    }
                }
            }

            Button(action: toggleRecording) {
                Label {
                    Text(isRecording ? .stop : .startRecording)
                } icon: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
                }
                .font(.title3)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : .accentColor)
            .controlSize(.large)
        }
        .padding(18)
        .frame(width: 340)
        .task { await setUp() }
        .onChange(of: settings.selectedCameraID) { newValue in
            cameraSelectionTask?.cancel()
            cameraSelectionTask = Task { await cameraDidChange(to: newValue) }
        }
        .onChange(of: settings.selectedMicrophoneID) { newValue in
            microphoneSelectionTask?.cancel()
            microphoneSelectionTask = Task { await cameraRecorder.selectMicrophone(deviceID: newValue) }
        }
        .onChange(of: settings.selectedDisplayID) { _ in showPreviewWindow() }
        .onChange(of: settings.overlayPosition) { _ in showPreviewWindow() }
        .onChange(of: settings.overlaySize) { _ in showPreviewWindow() }
        .onChange(of: settings.overlayShape) { _ in showPreviewWindow() }
        .onChange(of: settings.isCameraMirrored) { _ in showPreviewWindow() }
        .onChange(of: cameraRecorder.lastErrorMessage) { message in
            if let message { statusText = message }
        }
        .onChange(of: screenRecorder.lastErrorMessage) { message in
            if let message { statusText = message }
        }
    }

    private func setUp() async {
        await screenRecorder.refreshAvailableDisplays()
        if !screenRecorder.availableDisplays.contains(where: { $0.displayID == settings.selectedDisplayID }) {
            settings.selectedDisplayID = screenRecorder.availableDisplays.first?.displayID ?? 0
        }

        await cameraRecorder.refreshAvailableCameras()
        if previewWindowController == nil {
            previewWindowController = CameraPreviewWindowController(session: cameraRecorder.session)
        }
        if settings.selectedCameraID.isEmpty {
            settings.selectedCameraID = cameraRecorder.availableCameras.first?.uniqueID ?? ""
        } else {
            await cameraRecorder.selectCamera(deviceID: settings.selectedCameraID)
            guard !Task.isCancelled else { return }
            showPreviewWindow()
        }

        await cameraRecorder.refreshAvailableMicrophones()
        await cameraRecorder.selectMicrophone(deviceID: settings.selectedMicrophoneID)
    }

    private func cameraDidChange(to deviceID: String) async {
        guard !deviceID.isEmpty else { return }
        await cameraRecorder.selectCamera(deviceID: deviceID)
        guard !Task.isCancelled else { return }
        showPreviewWindow()
    }

    private func toggleRecording() {
        guard !isTransitioning else { return }
        isTransitioning = true
        Task {
            defer { isTransitioning = false }
            if isRecording {
                statusText = String(localized: .processingAndMergingVideo)
                let screenURL = await screenRecorder.stop()
                let cameraURL = await cameraRecorder.stopRecording()
                let screenStartTime = screenRecorder.startHostTime
                let cameraStartTime = cameraRecorder.startHostTime

                if let screenURL, let cameraURL {
                    let outputURL = try? await Compositor.combine(
                        screenURL: screenURL,
                        cameraURL: cameraURL,
                        screenStartTime: screenStartTime,
                        cameraStartTime: cameraStartTime,
                        edgeInsets: currentEdgeInsets,
                        settings: settings
                    )
                    lastRecordingURL = outputURL
                    statusText = outputURL != nil ? String(localized: .doneFileSaved) : String(localized: .mergeFailed)
                } else {
                    statusText = String(localized: .recordingFailed)
                }
                isRecording = false
            } else {
                lastRecordingURL = nil
                statusText = String(localized: .recording)
                async let screenStart: () = screenRecorder.start(displayID: settings.selectedDisplayID)
                async let cameraStart: () = cameraRecorder.startRecording()
                _ = await (screenStart, cameraStart)
                isRecording = true
                showPreviewWindow()
                if let previewWindowController {
                    await screenRecorder.excludeWindow(numbered: previewWindowController.windowNumber)
                }
            }
        }
    }

    private func showPreviewWindow() {
        guard let previewWindowController, let screen = recordedScreen else { return }
        currentEdgeInsets = dockAvoidingInsets(for: screen)
        let canvasSize = screen.frame.size
        let cameraSize = cameraRecorder.activeVideoDimensions ?? .zero
        let bubble = OverlayGeometry.frame(
            canvasSize: canvasSize,
            cameraSize: cameraSize,
            position: settings.overlayPosition,
            sizeFraction: settings.overlaySize,
            shape: settings.overlayShape,
            edgeInsets: currentEdgeInsets
        )
        let screenFrame = CGRect(
            x: screen.frame.origin.x + bubble.origin.x,
            y: screen.frame.origin.y + bubble.origin.y,
            width: bubble.width,
            height: bubble.height
        )
        previewWindowController.show(frame: screenFrame, shape: settings.overlayShape, mirrored: settings.isCameraMirrored)
    }

    private func dockAvoidingInsets(for screen: NSScreen) -> OverlayEdgeInsets {
        let full = screen.frame
        let visible = screen.visibleFrame
        return OverlayEdgeInsets(
            top: full.maxY - visible.maxY,
            left: visible.minX - full.minX,
            bottom: visible.minY - full.minY,
            right: full.maxX - visible.maxX
        )
    }

    private func displayName(for display: SCDisplay) -> String {
        if let screen = NSScreen.screens.first(where: { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == display.displayID
        }) {
            return screen.localizedName
        }
        return String(localized: .display(Int32(display.displayID)))
    }

    private var recordedScreen: NSScreen? {
        let targetDisplayID = screenRecorder.recordedDisplayID ?? settings.selectedDisplayID
        return NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == targetDisplayID
        } ?? NSScreen.main
    }
}

#Preview {
    ContentView()
}
