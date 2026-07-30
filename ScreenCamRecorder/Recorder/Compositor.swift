import Foundation
import AVFoundation
import CoreImage

/// Етап 5: Склеювання екрану + камери в один файл (post-processing підхід).
/// Накладає відео камери (з маскою круг/прямокутник) поверх запису екрану
/// у позицію та розмір з RecordingSettings.
enum Compositor {

    enum CompositorError: Error {
        case exportFailed
    }

    @MainActor
    static func combine(
        screenURL: URL,
        cameraURL: URL,
        settings: RecordingSettings
    ) async throws -> URL {

        let screenAsset = AVURLAsset(url: screenURL)
        let cameraAsset = AVURLAsset(url: cameraURL)

        let composition = AVMutableComposition()

        // TODO:
        // 1. Додати відеотреки screenAsset і cameraAsset в composition
        //    (composition.addMutableTrack(withMediaType: .video, ...))
        // 2. Створити AVMutableVideoComposition з custom compositor instruction,
        //    що малює screen-кадр як фон, а camera-кадр зверху:
        //      - масштабувати camera-кадр відповідно до settings.overlaySize
        //      - позиціювати відповідно до settings.overlayPosition
        //      - застосувати circle/rectangle маску (CIFilter, settings.overlayShape)
        // 3. Використати AVAssetExportSession(asset: composition, presetName: .highestQuality)
        //    з videoComposition = createdVideoComposition
        // 4. export.exportAsynchronously { ... }

        let outputURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenCamRecording-\(Date().timeIntervalSince1970).mov")

        // Заглушка: тут буде реальний export
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw CompositorError.exportFailed
        }
        export.outputURL = outputURL
        export.outputFileType = .mov

        await export.export()

        guard export.status == .completed else {
            throw CompositorError.exportFailed
        }

        return outputURL
    }
}
