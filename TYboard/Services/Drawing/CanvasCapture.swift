import UIKit
import PencilKit

/// Captures the current canvas drawing as an image for AI analysis
enum CanvasCapture {
    /// Render PKDrawing to a PNG image
    static func captureDrawing(_ drawing: PKDrawing, scale: CGFloat = 2.0) -> Data? {
        let bounds = drawing.bounds
        guard !bounds.isEmpty else { return nil }

        // Add padding around the drawing
        let padding: CGFloat = 20
        let paddedBounds = bounds.insetBy(dx: -padding, dy: -padding)

        let image = drawing.image(from: paddedBounds, scale: scale)
        return image.pngData()
    }

    /// Capture a UIView as PNG
    static func captureView(_ view: UIView) -> Data? {
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        return image.pngData()
    }
}
