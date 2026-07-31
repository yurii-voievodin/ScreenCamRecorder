import Foundation
import ScreenCaptureKit
import AVFoundation

@MainActor
final class ScreenRecorder: NSObject, ObservableObject {

    private var stream: SCStream?
    private var currentDisplay: SCDisplay?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var sessionStarted = false

    private(set) var startHostTime: CFTimeInterval?

    var recordedDisplayID: CGDirectDisplayID? { currentDisplay?.displayID }

    @Published private(set) var availableDisplays: [SCDisplay] = []
    @Published private(set) var lastErrorMessage: String?

    private let outputQueue = DispatchQueue(label: "com.yuriivoevodin.ScreenCamRecorder.screenOutput")

    func requestPermissionIfNeeded() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            print("Screen recording permission denied: \(error)")
            lastErrorMessage = "Немає дозволу на запис екрана"
            return false
        }
    }

    func refreshAvailableDisplays() async {
        guard await requestPermissionIfNeeded() else { return }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            availableDisplays = content.displays
        } catch {
            print("Failed to list available displays: \(error)")
        }
    }

    func start(displayID: CGDirectDisplayID?) async {
        guard await requestPermissionIfNeeded() else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            availableDisplays = content.displays
            let selectedDisplay = displayID.flatMap { id in content.displays.first { $0.displayID == id } }
            guard let display = selectedDisplay ?? content.displays.first else {
                print("No display available for screen capture")
                lastErrorMessage = "Дисплей недоступний"
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
            self.startHostTime = nil
            self.stream = stream
            self.currentDisplay = display

            try await stream.startCapture()
        } catch {
            print("Failed to start screen capture: \(error)")
        }
    }

    func excludeWindow(numbered windowNumber: Int) async {
        guard let stream, let currentDisplay else { return }
        do {
            var matchedWindow: SCWindow?
            for attempt in 0..<5 {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                if let window = content.windows.first(where: { Int($0.windowID) == windowNumber }) {
                    matchedWindow = window
                    break
                }
                if attempt < 4 {
                    try await Task.sleep(for: .milliseconds(100))
                }
            }
            guard let matchedWindow else {
                print("ScreenRecorder: could not find preview window (id=\(windowNumber)) to exclude from capture")
                return
            }
            let filter = SCContentFilter(display: currentDisplay, excludingWindows: [matchedWindow])
            try await stream.updateContentFilter(filter)
        } catch {
            print("ScreenRecorder: failed to exclude preview window from capture: \(error)")
        }
    }

    func stop() async -> URL? {
        if let stream {
            do {
                try await stream.stopCapture()
            } catch {
                print("Failed to stop screen capture: \(error)")
            }
        }
        stream = nil
        currentDisplay = nil

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
            startHostTime = ProcessInfo.processInfo.systemUptime
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
