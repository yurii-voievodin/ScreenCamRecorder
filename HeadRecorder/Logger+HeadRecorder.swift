import os

extension Logger {
    enum Category: String {
        case cameraRecorder = "CameraRecorder"
        case screenRecorder = "ScreenRecorder"
        case compositor = "Compositor"
    }

    private nonisolated static let subsystem = "com.yuriivoevodin.HeadRecorder"

    nonisolated static func category(_ category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
