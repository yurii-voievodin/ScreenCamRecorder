import Foundation
@preconcurrency import AVFoundation

final class CameraRecorder: NSObject, ObservableObject {

    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var availableMicrophones: [AVCaptureDevice] = []
    @Published private(set) var lastErrorMessage: String?

    let session = AVCaptureSession()
    private let sessionRunner = SessionRunner()
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var outputURL: URL?
    private var recordingFinished: CheckedContinuation<Void, Never>?

    private(set) var startHostTime: CFTimeInterval?

    private(set) var activeVideoDimensions: CGSize?

    func refreshAvailableCameras() async {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices
    }

    func refreshAvailableMicrophones() async {
        // .microphone requires macOS 14+; deployment target is 13.0, so fall back to
        // the older .builtInMicrophone type (deprecated in 14, but that's fine pre-14).
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone]
        } else {
            deviceTypes = [.builtInMicrophone]
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )
        availableMicrophones = discovery.devices
    }

    func requestPermissionIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func requestMicrophonePermissionIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }

    func selectCamera(deviceID: String) async {
        guard await requestPermissionIfNeeded() else {
            print("CameraRecorder: camera permission not granted (status=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue))")
            lastErrorMessage = String(localized: .cameraPermissionDenied)
            return
        }
        guard !Task.isCancelled else { return }

        if availableCameras.isEmpty {
            await refreshAvailableCameras()
        }
        guard !Task.isCancelled else { return }

        guard let device = availableCameras.first(where: { $0.uniqueID == deviceID }) ?? availableCameras.first else {
            print("No camera device available")
            lastErrorMessage = String(localized: .cameraUnavailable)
            return
        }

        if currentInput?.device.uniqueID != device.uniqueID {
            do {
                let input = try AVCaptureDeviceInput(device: device)

                session.beginConfiguration()
                if let currentInput {
                    session.removeInput(currentInput)
                }
                if session.canAddInput(input) {
                    session.addInput(input)
                    currentInput = input
                } else {
                    print("CameraRecorder: cannot add input for device \(device.localizedName)")
                }
                if movieOutput == nil {
                    let output = AVCaptureMovieFileOutput()
                    if session.canAddOutput(output) {
                        session.addOutput(output)
                        movieOutput = output
                    } else {
                        print("CameraRecorder: cannot add AVCaptureMovieFileOutput to session")
                    }
                }
                session.commitConfiguration()

                let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
                activeVideoDimensions = CGSize(width: Int(dimensions.width), height: Int(dimensions.height))
            } catch {
                print("Failed to configure camera input: \(error)")
                return
            }
        }

        await sessionRunner.start(session)
    }

    func selectMicrophone(deviceID: String) async {
        if deviceID == RecordingSettings.noMicrophoneID {
            if let audioInput {
                session.beginConfiguration()
                session.removeInput(audioInput)
                session.commitConfiguration()
                self.audioInput = nil
            }
            return
        }

        guard await requestMicrophonePermissionIfNeeded() else {
            print("CameraRecorder: microphone permission not granted (status=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue))")
            lastErrorMessage = String(localized: .microphonePermissionDenied)
            return
        }
        guard !Task.isCancelled else { return }

        if availableMicrophones.isEmpty {
            await refreshAvailableMicrophones()
        }
        guard !Task.isCancelled else { return }

        let device = deviceID.isEmpty
            ? AVCaptureDevice.default(for: .audio)
            : (availableMicrophones.first(where: { $0.uniqueID == deviceID }) ?? AVCaptureDevice.default(for: .audio))

        guard let device else {
            print("CameraRecorder: no microphone device available")
            lastErrorMessage = String(localized: .microphoneUnavailable)
            return
        }

        guard audioInput?.device.uniqueID != device.uniqueID else { return }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            if let audioInput {
                session.removeInput(audioInput)
            }
            if session.canAddInput(input) {
                session.addInput(input)
                audioInput = input
            } else {
                print("CameraRecorder: cannot add microphone input for device \(device.localizedName)")
            }
            session.commitConfiguration()
        } catch {
            print("CameraRecorder: failed to create microphone input: \(error)")
        }
    }

    func startRecording() async {
        guard let movieOutput else {
            print("CameraRecorder: camera not configured, cannot start recording")
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("camera-\(UUID().uuidString).mov")
        outputURL = url
        startHostTime = nil
        movieOutput.startRecording(to: url, recordingDelegate: self)
    }

    func stopRecording() async -> URL? {
        if let movieOutput, movieOutput.isRecording, recordingFinished == nil {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                recordingFinished = continuation
                movieOutput.stopRecording()
            }
        }

        return outputURL
    }
}

extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            startHostTime = ProcessInfo.processInfo.systemUptime
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error {
            print("Camera recording finished with error: \(error)")
        }
        Task { @MainActor in
            recordingFinished?.resume()
            recordingFinished = nil
        }
    }
}
