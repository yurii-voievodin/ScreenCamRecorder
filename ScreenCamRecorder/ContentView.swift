import SwiftUI

struct ContentView: View {
    @StateObject private var settings = RecordingSettings()
    @StateObject private var screenRecorder = ScreenRecorder()
    @StateObject private var cameraRecorder = CameraRecorder()

    @State private var isRecording = false
    @State private var statusText = "Готово до запису"

    var body: some View {
        VStack(spacing: 20) {
            Text("ScreenCam Recorder")
                .font(.title2)
                .bold()

            Text(statusText)
                .foregroundStyle(.secondary)

            // MARK: - Налаштування камери (Етап 6)
            GroupBox("Камера") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Пристрій", selection: $settings.selectedCameraID) {
                        ForEach(cameraRecorder.availableCameras, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }

                    Picker("Позиція", selection: $settings.overlayPosition) {
                        ForEach(OverlayPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }

                    HStack {
                        Text("Розмір")
                        Slider(value: $settings.overlaySize, in: 0.1...0.4)
                    }

                    Picker("Форма", selection: $settings.overlayShape) {
                        Text("Круг").tag(OverlayShape.circle)
                        Text("Прямокутник").tag(OverlayShape.rectangle)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 4)
            }

            // MARK: - Керування записом (Етапи 1-4)
            Button(action: toggleRecording) {
                Label(isRecording ? "Зупинити" : "Почати запис",
                      systemImage: isRecording ? "stop.circle.fill" : "record.circle")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRecording ? .red : .accentColor)
        }
        .padding(24)
        .frame(width: 360)
        .task {
            await cameraRecorder.refreshAvailableCameras()
        }
    }

    private func toggleRecording() {
        Task {
            if isRecording {
                statusText = "Обробка та склеювання відео…"
                let screenURL = await screenRecorder.stop()
                let cameraURL = await cameraRecorder.stop()

                // MARK: - Композитинг (Етап 5)
                if let screenURL, let cameraURL {
                    let outputURL = try? await Compositor.combine(
                        screenURL: screenURL,
                        cameraURL: cameraURL,
                        settings: settings
                    )
                    statusText = outputURL != nil ? "Готово! Файл збережено." : "Помилка склеювання."
                } else {
                    statusText = "Помилка запису."
                }
                isRecording = false
            } else {
                statusText = "Йде запис…"
                // Синхронний старт обох потоків (Етап 4)
                async let screenStart: () = screenRecorder.start()
                async let cameraStart: () = cameraRecorder.start(deviceID: settings.selectedCameraID)
                _ = await (screenStart, cameraStart)
                isRecording = true
            }
        }
    }
}

#Preview {
    ContentView()
}
