import CoreGraphics

enum OverlayGeometry {
    static let margin: CGFloat = 24

    static func frame(
        canvasSize: CGSize,
        cameraSize: CGSize,
        position: OverlayPosition,
        sizeFraction: Double,
        shape: OverlayShape
    ) -> CGRect {
        let size = overlaySize(canvasWidth: canvasSize.width, cameraSize: cameraSize, sizeFraction: sizeFraction, shape: shape)
        return CGRect(origin: origin(for: size, canvasSize: canvasSize, position: position), size: size)
    }

    static func overlaySize(canvasWidth: CGFloat, cameraSize: CGSize, sizeFraction: Double, shape: OverlayShape) -> CGSize {
        guard cameraSize.width > 0, cameraSize.height > 0 else {
            let side = canvasWidth * CGFloat(sizeFraction)
            return CGSize(width: side, height: side)
        }
        let overlayWidth = canvasWidth * CGFloat(sizeFraction)
        let scale = overlayWidth / cameraSize.width
        var size = CGSize(width: overlayWidth, height: cameraSize.height * scale)
        if shape == .circle {
            let diameter = min(size.width, size.height)
            size = CGSize(width: diameter, height: diameter)
        }
        return size
    }

    static func origin(for size: CGSize, canvasSize: CGSize, position: OverlayPosition) -> CGPoint {
        switch position {
        case .topLeft:
            return CGPoint(x: margin, y: canvasSize.height - size.height - margin)
        case .topRight:
            return CGPoint(x: canvasSize.width - size.width - margin, y: canvasSize.height - size.height - margin)
        case .bottomLeft:
            return CGPoint(x: margin, y: margin)
        case .bottomRight:
            return CGPoint(x: canvasSize.width - size.width - margin, y: margin)
        }
    }
}
