import Foundation

enum OverlayPosition: String, CaseIterable, Identifiable {
    case topLeft, topRight, bottomLeft, bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: return "Верхній лівий"
        case .topRight: return "Верхній правий"
        case .bottomLeft: return "Нижній лівий"
        case .bottomRight: return "Нижній правий"
        }
    }
}

enum OverlayShape {
    case circle
    case rectangle
}

@MainActor
final class RecordingSettings: ObservableObject {
    @Published var selectedCameraID: String = ""
    @Published var overlayPosition: OverlayPosition = .bottomRight
    @Published var overlaySize: Double = 0.2
    @Published var overlayShape: OverlayShape = .circle
}
