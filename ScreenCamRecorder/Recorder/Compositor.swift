import Foundation
import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins

enum Compositor {

    enum CompositorError: Error {
        case exportFailed
        case noVideoTrack
    }

    @MainActor
    static func combine(
        screenURL: URL,
        cameraURL: URL,
        screenStartTime: CFTimeInterval?,
        cameraStartTime: CFTimeInterval?,
        settings: RecordingSettings
    ) async throws -> URL {

        let screenAsset = AVURLAsset(url: screenURL)
        let cameraAsset = AVURLAsset(url: cameraURL)

        guard let screenTrack = try await screenAsset.loadTracks(withMediaType: .video).first,
              let cameraTrack = try await cameraAsset.loadTracks(withMediaType: .video).first else {
            throw CompositorError.noVideoTrack
        }

        let composition = AVMutableComposition()
        guard let compScreenTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let compCameraTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CompositorError.exportFailed
        }

        let screenDuration = try await screenAsset.load(.duration)
        let cameraDuration = try await cameraAsset.load(.duration)

        let (screenTrim, cameraTrim) = startTrims(screenStartTime: screenStartTime, cameraStartTime: cameraStartTime)
        let screenAvailable = max(.zero, screenDuration - screenTrim)
        let cameraAvailable = max(.zero, cameraDuration - cameraTrim)
        let duration = min(screenAvailable, cameraAvailable)
        let range = CMTimeRange(start: .zero, duration: duration)

        try compScreenTrack.insertTimeRange(CMTimeRange(start: screenTrim, duration: duration), of: screenTrack, at: .zero)
        try compCameraTrack.insertTimeRange(CMTimeRange(start: cameraTrim, duration: duration), of: cameraTrack, at: .zero)

        if let cameraAudioTrack = try await cameraAsset.loadTracks(withMediaType: .audio).first,
           let compAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            try compAudioTrack.insertTimeRange(CMTimeRange(start: cameraTrim, duration: duration), of: cameraAudioTrack, at: .zero)
        }

        let renderSize = try await screenTrack.load(.naturalSize)

        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        let instruction = OverlayInstruction(
            timeRange: range,
            screenTrackID: compScreenTrack.trackID,
            cameraTrackID: compCameraTrack.trackID,
            renderSize: renderSize,
            position: settings.overlayPosition,
            sizeFraction: settings.overlaySize,
            shape: settings.overlayShape
        )
        videoComposition.instructions = [instruction]
        videoComposition.customVideoCompositorClass = OverlayCompositor.self

        let outputURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenCamRecording-\(Date().timeIntervalSince1970).mov")

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw CompositorError.exportFailed
        }
        export.videoComposition = videoComposition
        export.outputURL = outputURL
        export.outputFileType = .mov

        await export.export()

        guard export.status == .completed else {
            print("Compositor export failed: \(export.error?.localizedDescription ?? "unknown error")")
            throw CompositorError.exportFailed
        }

        return outputURL
    }

    private static func startTrims(
        screenStartTime: CFTimeInterval?,
        cameraStartTime: CFTimeInterval?
    ) -> (screen: CMTime, camera: CMTime) {
        guard let screenStartTime, let cameraStartTime else { return (.zero, .zero) }
        let offsetSeconds = cameraStartTime - screenStartTime
        let offset = CMTime(seconds: abs(offsetSeconds), preferredTimescale: 600)
        if offsetSeconds > 0 {
            return (offset, .zero)
        } else if offsetSeconds < 0 {
            return (.zero, offset)
        }
        return (.zero, .zero)
    }
}

private final class OverlayInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid

    let screenTrackID: CMPersistentTrackID
    let cameraTrackID: CMPersistentTrackID
    let renderSize: CGSize
    let position: OverlayPosition
    let sizeFraction: Double
    let shape: OverlayShape

    init(
        timeRange: CMTimeRange,
        screenTrackID: CMPersistentTrackID,
        cameraTrackID: CMPersistentTrackID,
        renderSize: CGSize,
        position: OverlayPosition,
        sizeFraction: Double,
        shape: OverlayShape
    ) {
        self.timeRange = timeRange
        self.screenTrackID = screenTrackID
        self.cameraTrackID = cameraTrackID
        self.renderSize = renderSize
        self.position = position
        self.sizeFraction = sizeFraction
        self.shape = shape
        self.requiredSourceTrackIDs = [NSNumber(value: screenTrackID), NSNumber(value: cameraTrackID)]
        super.init()
    }
}

private final class OverlayCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {

    let sourcePixelBufferAttributes: [String: Any]? = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]
    let requiredPixelBufferAttributesForRenderContext: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
    ]

    private let context = CIContext()
    private let stateQueue = DispatchQueue(label: "com.yuriivoevodin.ScreenCamRecorder.overlayCompositor")
    private var renderContext: AVVideoCompositionRenderContext?

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        stateQueue.sync { renderContext = newRenderContext }
    }

    func cancelAllPendingVideoCompositionRequests() {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? OverlayInstruction,
              let screenBuffer = request.sourceFrame(byTrackID: instruction.screenTrackID),
              let cameraBuffer = request.sourceFrame(byTrackID: instruction.cameraTrackID) else {
            request.finish(with: NSError(domain: "Compositor", code: -1))
            return
        }

        let screenImage = CIImage(cvPixelBuffer: screenBuffer)
        let overlay = Self.makeOverlay(
            from: CIImage(cvPixelBuffer: cameraBuffer),
            renderSize: instruction.renderSize,
            position: instruction.position,
            sizeFraction: instruction.sizeFraction,
            shape: instruction.shape
        )
        let composited = overlay.composited(over: screenImage)

        guard let outputBuffer = (stateQueue.sync { renderContext })?.newPixelBuffer() else {
            request.finish(with: NSError(domain: "Compositor", code: -2))
            return
        }

        context.render(composited, to: outputBuffer)
        request.finish(withComposedVideoFrame: outputBuffer)
    }

    private static func makeOverlay(
        from cameraImage: CIImage,
        renderSize: CGSize,
        position: OverlayPosition,
        sizeFraction: Double,
        shape: OverlayShape
    ) -> CIImage {
        let overlayWidth = renderSize.width * CGFloat(sizeFraction)
        let cameraExtent = cameraImage.extent
        let scale = overlayWidth / cameraExtent.width
        var scaled = cameraImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        var scaledExtent = scaled.extent

        switch shape {
        case .circle:
            let diameter = min(scaledExtent.width, scaledExtent.height)
            let cropRect = CGRect(
                x: scaledExtent.midX - diameter / 2,
                y: scaledExtent.midY - diameter / 2,
                width: diameter,
                height: diameter
            )
            scaled = scaled.cropped(to: cropRect)
            scaledExtent = scaled.extent

            let gradient = CIFilter.radialGradient()
            gradient.center = CGPoint(x: cropRect.midX, y: cropRect.midY)
            gradient.radius0 = Float(diameter / 2 - 1)
            gradient.radius1 = Float(diameter / 2)
            gradient.color0 = CIColor(red: 1, green: 1, blue: 1, alpha: 1)
            gradient.color1 = CIColor(red: 1, green: 1, blue: 1, alpha: 0)

            if let mask = gradient.outputImage?.cropped(to: cropRect) {
                let blend = CIFilter.blendWithMask()
                blend.inputImage = scaled
                blend.maskImage = mask
                if let masked = blend.outputImage {
                    scaled = masked
                }
            }

        case .rectangle:
            break
        }

        let origin = OverlayGeometry.origin(for: scaledExtent.size, canvasSize: renderSize, position: position)

        let translation = CGAffineTransform(
            translationX: origin.x - scaledExtent.origin.x,
            y: origin.y - scaledExtent.origin.y
        )
        return scaled.transformed(by: translation)
    }
}
