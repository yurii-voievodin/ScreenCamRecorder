import CoreGraphics

struct OverlayEdgeInsets: Sendable {
    var top: CGFloat = 0
    var left: CGFloat = 0
    var bottom: CGFloat = 0
    var right: CGFloat = 0

    static let zero = OverlayEdgeInsets()
}

nonisolated enum OverlayGeometry {
    static let margin: CGFloat = 24
    static let rectangleCornerRadiusFraction: CGFloat = 0.16

    static func rectangleCornerRadius(for size: CGSize) -> CGFloat {
        min(size.width, size.height) * rectangleCornerRadiusFraction
    }

    static func frame(
        canvasSize: CGSize,
        cameraSize: CGSize,
        position: OverlayPosition,
        sizeFraction: Double,
        shape: OverlayShape,
        edgeInsets: OverlayEdgeInsets
    ) -> CGRect {
        let size = overlaySize(canvasWidth: canvasSize.width, cameraSize: cameraSize, sizeFraction: sizeFraction, shape: shape)
        return CGRect(origin: origin(for: size, canvasSize: canvasSize, position: position, edgeInsets: edgeInsets), size: size)
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

    static func origin(for size: CGSize, canvasSize: CGSize, position: OverlayPosition, edgeInsets: OverlayEdgeInsets) -> CGPoint {
        switch position {
        case .topLeft:
            return CGPoint(x: margin + edgeInsets.left, y: canvasSize.height - size.height - margin - edgeInsets.top)
        case .topRight:
            return CGPoint(x: canvasSize.width - size.width - margin - edgeInsets.right, y: canvasSize.height - size.height - margin - edgeInsets.top)
        case .bottomLeft:
            return CGPoint(x: margin + edgeInsets.left, y: margin + edgeInsets.bottom)
        case .bottomRight:
            return CGPoint(x: canvasSize.width - size.width - margin - edgeInsets.right, y: margin + edgeInsets.bottom)
        }
    }
}
