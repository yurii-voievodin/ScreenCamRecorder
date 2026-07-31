@preconcurrency import AVFoundation

actor SessionRunner {
    func start(_ session: AVCaptureSession) {
        if !session.isRunning {
            session.startRunning()
        }
    }
}
