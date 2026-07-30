import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var settings = RecordingSettings()
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var cameraRecorder = CameraRecorder()

    @State private var isRecording = false
    @State private var statusText = "Готово до запису"
    @State private var lastRecordingURL: URL?
    @State private var previewWindowController: CameraPreviewWindowController?

    var body: some View {
        VStack(spacing: 20) {
            Text("ScreenCam Recorder")
                .font(.title2)
                .bold()

            Text(statusText)
                .foregroundStyle(.secondary)

            GroupBox("Камера") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Пристрій", selection: $settings.selectedCameraID) {
                        if cameraRecorder.availableCameras.isEmpty {
                            Text("Немає камери").tag("")
                        }
                        ForEach(cameraRecorder.availableCameras, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }

                    Picker("Позиція", selection: $settings.overlayPosition) {
                        ForEach(OverlayPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                    .disabled(isRecording)

                    HStack {
                        Text("Розмір")
                        Slider(value: $settings.overlaySize, in: 0.1...0.4)
                    }
                    .disabled(isRecording)

                    Picker("Форма", selection: $settings.overlayShape) {
                        Text("Круг").tag(OverlayShape.circle)
                        Text("Прямокутник").tag(OverlayShape.rectangle)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isRecording)
                }
                .padding(.top, 4)
            }

            Button(action: toggleRecording) {
                Label(isRecording ? "Зупинити" : "Почати запис",
                      systemImage: isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : .accentColor)

            if let lastRecordingURL {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
                } label: {
                    Label("Показати у Finder", systemImage: "folder")
                }
            }
        }
        .padding(24)
        .frame(width: 360)
        .task {
            await cameraRecorder.refreshAvailableCameras()
            if settings.selectedCameraID.isEmpty {
                settings.selectedCameraID = cameraRecorder.availableCameras.first?.uniqueID ?? ""
            }
            if previewWindowController == nil {
                previewWindowController = CameraPreviewWindowController(session: cameraRecorder.session)
            }
        }
    }

    private func toggleRecording() {
        Task {
            if isRecording {
                previewWindowController?.hide()
                statusText = "Обробка та склеювання відео…"
                let screenURL = await screenRecorder.stop()
                let cameraURL = await cameraRecorder.stop()
                let screenStartTime = screenRecorder.startHostTime
                let cameraStartTime = cameraRecorder.startHostTime

                if let screenURL, let cameraURL {
                    let outputURL = try? await Compositor.combine(
                        screenURL: screenURL,
                        cameraURL: cameraURL,
                        screenStartTime: screenStartTime,
                        cameraStartTime: cameraStartTime,
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
                async let screenStart: () = screenRecorder.start()
                async let cameraStart: () = cameraRecorder.start(deviceID: settings.selectedCameraID)
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
        let canvasSize = screen.frame.size
        let cameraSize = cameraRecorder.activeVideoDimensions ?? .zero
        let bubble = OverlayGeometry.frame(
            canvasSize: canvasSize,
            cameraSize: cameraSize,
            position: settings.overlayPosition,
            sizeFraction: settings.overlaySize,
            shape: settings.overlayShape
        )
        let screenFrame = CGRect(
            x: screen.frame.origin.x + bubble.origin.x,
            y: screen.frame.origin.y + bubble.origin.y,
            width: bubble.width,
            height: bubble.height
        )
        previewWindowController.show(frame: screenFrame, shape: settings.overlayShape)
    }

    private var recordedScreen: NSScreen? {
        guard let recordedDisplayID = screenRecorder.recordedDisplayID else { return NSScreen.main }
        return NSScreen.screens.first { screen in
            (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) == recordedDisplayID
        } ?? NSScreen.main
    }
}

#Preview {
    ContentView()
}
