import os

extension Logger {
    enum Category: String {
        case cameraRecorder = "CameraRecorder"
        case screenRecorder = "ScreenRecorder"
        case compositor = "Compositor"
    }

    private static let subsystem = "com.yuriivoevodin.HeadRecorder"

    static func category(_ category: Category) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }
}
