import Foundation
import ScreenCaptureKit
import AVFoundation

/// Етап 2: Запис екрану через ScreenCaptureKit.
@MainActor
final class ScreenRecorder: NSObject, ObservableObject {

    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStarted = false

    private let outputQueue = DispatchQueue(label: "com.yuriivoevodin.ScreenCamRecorder.screenOutput")

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

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                print("No display available for screen capture")
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])

            let config = SCStreamConfiguration()
            config.width = display.width
            config.height = display.height
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.showsCursor = true
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("screen-\(UUID().uuidString).mov")

            let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: config.width,
                AVVideoHeightKey: config.height
            ]
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            input.expectsMediaDataInRealTime = true
            writer.add(input)

            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)

            writer.startWriting()

            self.outputURL = url
            self.assetWriter = writer
            self.videoInput = input
            self.sessionStarted = false
            self.stream = stream

            try await stream.startCapture()
        } catch {
            print("Failed to start screen capture: \(error)")
        }
    }

    /// Зупиняє запис і повертає URL готового файлу.
    func stop() async -> URL? {
        if let stream {
            do {
                try await stream.stopCapture()
            } catch {
                print("Failed to stop screen capture: \(error)")
            }
        }
        stream = nil

        videoInput?.markAsFinished()
        await assetWriter?.finishWriting()
        if let writer = assetWriter, writer.status != .completed {
            print("AVAssetWriter finished with status \(writer.status.rawValue): \(writer.error?.localizedDescription ?? "no error")")
        }

        let url = outputURL
        assetWriter = nil
        videoInput = nil
        return url
    }

    fileprivate func handle(_ sampleBuffer: CMSampleBuffer) {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let statusRawValue = attachments.first?[.status] as? Int,
              let status = SCFrameStatus(rawValue: statusRawValue),
              status == .complete else { return }

        guard let writer = assetWriter, let input = videoInput else { return }

        if writer.status == .failed {
            print("AVAssetWriter failed: \(writer.error?.localizedDescription ?? "unknown error")")
            return
        }
        guard writer.status == .writing else { return }

        if !sessionStarted {
            writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp)
            sessionStarted = true
        }
        if input.isReadyForMoreMediaData {
            input.append(sampleBuffer)
        }
    }
}

extension ScreenRecorder: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid else { return }
        Task { @MainActor in
            self.handle(sampleBuffer)
        }
    }
}

extension ScreenRecorder: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Screen capture stream stopped with error: \(error)")
    }
}
