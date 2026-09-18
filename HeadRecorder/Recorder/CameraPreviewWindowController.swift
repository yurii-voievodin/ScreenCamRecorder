import AppKit
import AVFoundation

final class CameraPreviewWindowController: NSWindowController {

    private let previewLayer: AVCaptureVideoPreviewLayer
    private let maskLayer = CAShapeLayer()

    var windowNumber: Int { window?.windowNumber ?? 0 }

    init(session: AVCaptureSession) {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill

        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.addSublayer(previewLayer)
        window.contentView = contentView

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(frame: CGRect, shape: OverlayShape, mirrored: Bool) {
        guard let window else { return }
        window.setFrame(frame, display: true)

        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = CGRect(origin: .zero, size: frame.size)
        switch shape {
        case .circle:
            maskLayer.path = CGPath(ellipseIn: previewLayer.bounds, transform: nil)
        case .rectangle:
            let radius = OverlayGeometry.rectangleCornerRadius(for: previewLayer.bounds.size)
            maskLayer.path = CGPath(roundedRect: previewLayer.bounds, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
        previewLayer.mask = maskLayer
        CATransaction.commit()

        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}
