import Foundation
@preconcurrency import AVFoundation

/// Етап 3: Запис з камери через AVCaptureSession.
@MainActor
final class CameraRecorder: NSObject, ObservableObject {

    @Published var availableCameras: [AVCaptureDevice] = []

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.yuriivoevodin.ScreenCamRecorder.cameraSession")
    private var movieOutput: AVCaptureMovieFileOutput?
    private var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var outputURL: URL?
    private var recordingFinished: CheckedContinuation<Void, Never>?

    /// Оновлює список доступних камер для Picker в ContentView.
    func refreshAvailableCameras() async {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        availableCameras = discovery.devices
    }

    /// Запитує дозвіл на камеру.
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

    /// Запитує дозвіл на мікрофон. Звук не обов'язковий — відмова не блокує запис відео.
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

    /// Старт запису з обраної камери. Викликається паралельно з ScreenRecorder.start() (Етап 4).
    func start(deviceID: String) async {
        guard await requestPermissionIfNeeded() else {
            print("CameraRecorder: camera permission not granted (status=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue))")
            return
        }

        if availableCameras.isEmpty {
            // AVCaptureDevice.DiscoverySession іноді порожній одразу після запуску
            // (CoreMediaIO ще не встиг зареєструвати пристрої) — пробуємо ще раз.
            await refreshAvailableCameras()
        }

        guard let device = availableCameras.first(where: { $0.uniqueID == deviceID }) ?? availableCameras.first else {
            print("No camera device available")
            return
        }

        var microphone: AVCaptureDevice?
        if audioInput == nil {
            if await requestMicrophonePermissionIfNeeded() {
                microphone = AVCaptureDevice.default(for: .audio)
                if microphone == nil {
                    print("CameraRecorder: no default audio input device found")
                }
            } else {
                print("CameraRecorder: microphone permission not granted (status=\(AVCaptureDevice.authorizationStatus(for: .audio).rawValue))")
            }
        }

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
            if let microphone {
                do {
                    let micInput = try AVCaptureDeviceInput(device: microphone)
                    if session.canAddInput(micInput) {
                        session.addInput(micInput)
                        audioInput = micInput
                    } else {
                        print("CameraRecorder: cannot add microphone input")
                    }
                } catch {
                    print("CameraRecorder: failed to create microphone input: \(error)")
                }
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

            guard let movieOutput else {
                print("CameraRecorder: movieOutput is nil after configuration, aborting start")
                return
            }

            let session = self.session
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                sessionQueue.async {
                    if !session.isRunning {
                        session.startRunning()
                    }
                    continuation.resume()
                }
            }

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("camera-\(UUID().uuidString).mov")
            outputURL = url
            movieOutput.startRecording(to: url, recordingDelegate: self)
        } catch {
            print("Failed to start camera capture: \(error)")
        }
    }

    /// Зупиняє запис і повертає URL готового файлу.
    func stop() async -> URL? {
        if let movieOutput, movieOutput.isRecording {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                recordingFinished = continuation
                movieOutput.stopRecording()
            }
        }

        let session = self.session
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if session.isRunning {
                    session.stopRunning()
                }
                continuation.resume()
            }
        }

        return outputURL
    }
}

extension CameraRecorder: AVCaptureFileOutputRecordingDelegate {
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
