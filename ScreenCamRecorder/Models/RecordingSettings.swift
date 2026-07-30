import Foundation
import CoreGraphics

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

enum OverlayShape: String, CaseIterable {
    case circle
    case rectangle
}

@MainActor
final class RecordingSettings: ObservableObject {
    private enum Keys {
        static let selectedCameraID = "selectedCameraID"
        static let selectedDisplayID = "selectedDisplayID"
        static let overlayPosition = "overlayPosition"
        static let overlaySize = "overlaySize"
        static let overlayShape = "overlayShape"
    }

    @Published var selectedCameraID: String {
        didSet { UserDefaults.standard.set(selectedCameraID, forKey: Keys.selectedCameraID) }
    }
    @Published var selectedDisplayID: CGDirectDisplayID {
        didSet { UserDefaults.standard.set(Int(selectedDisplayID), forKey: Keys.selectedDisplayID) }
    }
    @Published var overlayPosition: OverlayPosition {
        didSet { UserDefaults.standard.set(overlayPosition.rawValue, forKey: Keys.overlayPosition) }
    }
    @Published var overlaySize: Double {
        didSet { UserDefaults.standard.set(overlaySize, forKey: Keys.overlaySize) }
    }
    @Published var overlayShape: OverlayShape {
        didSet { UserDefaults.standard.set(overlayShape.rawValue, forKey: Keys.overlayShape) }
    }

    init() {
        let defaults = UserDefaults.standard
        selectedCameraID = defaults.string(forKey: Keys.selectedCameraID) ?? ""
        selectedDisplayID = CGDirectDisplayID(defaults.integer(forKey: Keys.selectedDisplayID))
        overlayPosition = (defaults.string(forKey: Keys.overlayPosition)).flatMap(OverlayPosition.init) ?? .bottomRight
        overlaySize = defaults.object(forKey: Keys.overlaySize) as? Double ?? 0.2
        overlayShape = (defaults.string(forKey: Keys.overlayShape)).flatMap(OverlayShape.init) ?? .circle
    }
}
