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

/// Налаштування запису: обраний пристрій камери, позиція/розмір/форма оверлею.
/// Використовується UI (ContentView) і Compositor для фінального склеювання (Етап 5, 6).
@MainActor
final class RecordingSettings: ObservableObject {
    @Published var selectedCameraID: String = ""
    @Published var overlayPosition: OverlayPosition = .bottomRight
    @Published var overlaySize: Double = 0.2 // частка ширини екрану
    @Published var overlayShape: OverlayShape = .circle
}
