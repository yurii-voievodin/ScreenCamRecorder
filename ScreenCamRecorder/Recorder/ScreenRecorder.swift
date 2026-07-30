import Foundation
import ScreenCaptureKit
import AVFoundation

/// Етап 2: Запис екрану через ScreenCaptureKit.
/// TODO: реалізувати SCStream, вибір дисплея/вікна, запис у .mov через AVAssetWriter.
@MainActor
final class ScreenRecorder: NSObject, ObservableObject {

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var outputURL: URL?

    /// Запитує дозвіл на запис екрану (System Settings → Privacy & Security → Screen Recording).
    func requestPermissionIfNeeded() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            print("Screen recording permission denied: \(error)")
            return false
        }
    }

    /// Старт запису екрану. Викликається паралельно з CameraRecorder.start() (Етап 4).
    func start() async {
        guard await requestPermissionIfNeeded() else { return }

        // TODO:
        // 1. SCShareableContent.current -> обрати SCDisplay
        // 2. Створити SCStreamConfiguration (roзмір, FPS, показувати курсор)
        // 3. SCStream(filter:configuration:delegate:)
        // 4. AVAssetWriter -> запис вихідних buffers у tmp .mov файл
        // 5. stream.startCapture()

        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("screen-\(UUID().uuidString).mov")
    }

    /// Зупиняє запис і повертає URL готового файлу.
    func stop() async -> URL? {
        // TODO: stream?.stopCapture(), закрити assetWriter
        return outputURL
    }
}
