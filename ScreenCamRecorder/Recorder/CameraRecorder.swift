import Foundation
import AVFoundation

/// Етап 3: Запис з камери через AVCaptureSession.
/// TODO: реалізувати AVCaptureSession, вибір пристрою, запис у окремий .mov файл.
@MainActor
final class CameraRecorder: NSObject, ObservableObject {

    @Published var availableCameras: [AVCaptureDevice] = []

    private let session = AVCaptureSession()
    private var movieOutput: AVCaptureMovieFileOutput?
    private var outputURL: URL?

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

    /// Старт запису з обраної камери. Викликається паралельно з ScreenRecorder.start() (Етап 4).
    func start(deviceID: String) async {
        guard await requestPermissionIfNeeded() else { return }

        // TODO:
        // 1. Знайти AVCaptureDevice за deviceID (або перший доступний)
        // 2. session.addInput(AVCaptureDeviceInput(device:))
        // 3. movieOutput = AVCaptureMovieFileOutput(); session.addOutput(movieOutput)
        // 4. session.startRunning()
        // 5. movieOutput.startRecording(to: tmpURL, recordingDelegate: self)

        outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("camera-\(UUID().uuidString).mov")
    }

    /// Зупиняє запис і повертає URL готового файлу.
    func stop() async -> URL? {
        // TODO: movieOutput?.stopRecording(), session.stopRunning()
        return outputURL
    }
}
