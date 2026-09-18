import Foundation
import CoreGraphics

enum OverlayPosition: String, CaseIterable, Identifiable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft: return String(localized: .topLeft)
        case .topRight: return String(localized: .topRight)
        case .bottomLeft: return String(localized: .bottomLeft)
        case .bottomRight: return String(localized: .bottomRight)
        }
    }
}

enum OverlayShape: String, CaseIterable, Sendable {
    case circle
    case rectangle

    var iconName: String {
        switch self {
        case .circle: return "circle.fill"
        case .rectangle: return "rectangle.fill"
        }
    }
}

final class RecordingSettings: ObservableObject {
    static let noMicrophoneID = "none"

    private enum Keys {
        static let selectedCameraID = "selectedCameraID"
        static let selectedMicrophoneID = "selectedMicrophoneID"
        static let selectedDisplayID = "selectedDisplayID"
        static let overlayPosition = "overlayPosition"
        static let overlaySize = "overlaySize"
        static let overlayShape = "overlayShape"
        static let isCameraMirrored = "isCameraMirrored"
    }

    @Published var selectedCameraID: String {
        didSet { UserDefaults.standard.set(selectedCameraID, forKey: Keys.selectedCameraID) }
    }
    @Published var selectedMicrophoneID: String {
        didSet { UserDefaults.standard.set(selectedMicrophoneID, forKey: Keys.selectedMicrophoneID) }
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
    @Published var isCameraMirrored: Bool {
        didSet { UserDefaults.standard.set(isCameraMirrored, forKey: Keys.isCameraMirrored) }
    }

    init() {
        let defaults = UserDefaults.standard
        selectedCameraID = defaults.string(forKey: Keys.selectedCameraID) ?? ""
        selectedMicrophoneID = defaults.string(forKey: Keys.selectedMicrophoneID) ?? ""
        selectedDisplayID = CGDirectDisplayID(defaults.integer(forKey: Keys.selectedDisplayID))
        overlayPosition = (defaults.string(forKey: Keys.overlayPosition)).flatMap(OverlayPosition.init) ?? .bottomRight
        overlaySize = defaults.object(forKey: Keys.overlaySize) as? Double ?? 0.2
        overlayShape = (defaults.string(forKey: Keys.overlayShape)).flatMap(OverlayShape.init) ?? .circle
        isCameraMirrored = defaults.object(forKey: Keys.isCameraMirrored) as? Bool ?? false
    }
}
