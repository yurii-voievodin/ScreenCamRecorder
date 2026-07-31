import SwiftUI
import AppKit
import ScreenCaptureKit

struct ContentView: View {
    @StateObject private var settings = RecordingSettings()
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var cameraRecorder = CameraRecorder()

    @State private var isRecording = false
    @State private var statusText = "Готово до запису"
    @State private var lastRecordingURL: URL?
    @State private var previewWindowController: CameraPreviewWindowController?
    @State private var currentEdgeInsets = OverlayEdgeInsets.zero

    var body: some View {
        VStack(spacing: 14) {
            statusRow

            card {
                VStack(alignment: .leading, spacing: 10) {
                    sourceRow(icon: "display", help: "Дисплей") {
                        Picker("Дисплей", selection: $settings.selectedDisplayID) {
                            if screenRecorder.availableDisplays.isEmpty {
                                Text("Немає екрана").tag(CGDirectDisplayID(0))
                            }
                            ForEach(screenRecorder.availableDisplays, id: \.displayID) { display in
                                Text(displayName(for: display)).tag(display.displayID)
                            }
                        }
                        .disabled(isRecording)
                    }

                    Divider()

                    sourceRow(icon: "video.fill", help: "Камера") {
                        Picker("Камера", selection: $settings.selectedCameraID) {
                            if cameraRecorder.availableCameras.isEmpty {
                                Text("Немає камери").tag("")
                            }
                            ForEach(cameraRecorder.availableCameras, id: \.uniqueID) { device in
                                Text(device.localizedName).tag(device.uniqueID)
                            }
                        }
                    }

                    Divider()

                    sourceRow(icon: "mic.fill", help: "Мікрофон") {
                        Picker("Мікрофон", selection: $settings.selectedMicrophoneID) {
                            Text("Системний мікрофон").tag("")
                            ForEach(cameraRecorder.availableMicrophones, id: \.uniqueID) { device in
                                Text(device.localizedName).tag(device.uniqueID)
                            }
                            Text("Без звуку").tag(RecordingSettings.noMicrophoneID)
                        }
                    }
                }
            }

            card {
                HStack(alignment: .center, spacing: 18) {
                    CornerPositionPicker(selection: $settings.overlayPosition, isEnabled: !isRecording)

                    VStack(spacing: 10) {
                        Picker("Форма", selection: $settings.overlayShape) {
                            ForEach(OverlayShape.allCases, id: \.self) { shape in
                                Image(systemName: shape.iconName).tag(shape)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .disabled(isRecording)
                        .help("Форма накладення камери")

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
                Label(isRecording ? "Зупинити" : "Почати запис",
                      systemImage: isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.title3)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : .accentColor)
            .controlSize(.large)
        }
        .padding(18)
        .frame(width: 340)
        .task {
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
                showPreviewWindow()
            }

            await cameraRecorder.refreshAvailableMicrophones()
            await cameraRecorder.selectMicrophone(deviceID: settings.selectedMicrophoneID)
        }
        .onChange(of: settings.selectedCameraID) { newValue in
            guard !newValue.isEmpty else { return }
            Task {
                await cameraRecorder.selectCamera(deviceID: newValue)
                showPreviewWindow()
            }
        }
        .onChange(of: settings.selectedMicrophoneID) { newValue in
            Task {
                await cameraRecorder.selectMicrophone(deviceID: newValue)
            }
        }
        .onChange(of: settings.selectedDisplayID) { _ in showPreviewWindow() }
        .onChange(of: settings.overlayPosition) { _ in showPreviewWindow() }
        .onChange(of: settings.overlaySize) { _ in showPreviewWindow() }
        .onChange(of: settings.overlayShape) { _ in showPreviewWindow() }
    }

    private var statusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: isRecording ? "record.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isRecording ? .red : .secondary)
            Text(statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let lastRecordingURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
                } label: {
                    Label("Показати у Finder", systemImage: "folder")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
                .layoutPriority(1)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.15)))
    }

    private func sourceRow<Content: View>(
        icon: String,
        help: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            content()
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(help)
    }

    private func toggleRecording() {
        Task {
            if isRecording {
                statusText = "Обробка та склеювання відео…"
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
                    statusText = outputURL != nil ? "Готово! Файл збережено." : "Помилка склеювання."
                } else {
                    statusText = "Помилка запису."
                }
                isRecording = false
            } else {
                lastRecordingURL = nil
                statusText = "Йде запис…"
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
        previewWindowController.show(frame: screenFrame, shape: settings.overlayShape)
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
        return "Дисплей \(display.displayID)"
    }

    private var recordedScreen: NSScreen? {
        let targetDisplayID = screenRecorder.recordedDisplayID ?? settings.selectedDisplayID
        return NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == targetDisplayID
        } ?? NSScreen.main
    }
}

private struct CornerPositionPicker: View {
    @Binding var selection: OverlayPosition
    var isEnabled: Bool = true

    private let size = CGSize(width: 64, height: 40)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    dot(for: .topLeft)
                    Spacer(minLength: 0)
                    dot(for: .topRight)
                }
                Spacer(minLength: 0)
                HStack(spacing: 0) {
                    dot(for: .bottomLeft)
                    Spacer(minLength: 0)
                    dot(for: .bottomRight)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private func dot(for position: OverlayPosition) -> some View {
        let isSelected = selection == position
        return Circle()
            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
            .frame(width: isSelected ? 14 : 8, height: isSelected ? 14 : 8)
            .padding(6)
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
                selection = position
            }
            .help(position.title)
    }
}

#Preview {
    ContentView()
}
