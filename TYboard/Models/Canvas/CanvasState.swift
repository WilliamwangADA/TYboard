import SwiftUI
import PencilKit

@Observable
final class CanvasState {
    var scale: CGFloat = 1.0
    var offset: CGPoint = .zero
    var drawing: PKDrawing = PKDrawing()
    var isPreviewVisible: Bool = true
    var previewWidthRatio: CGFloat = 1.0 / 3.0

    // Canvas content size (virtual infinite canvas)
    let canvasSize = CGSize(width: 10000, height: 10000)
    let canvasCenter = CGPoint(x: 5000, y: 5000)

    // Zoom limits
    let minScale: CGFloat = 0.1
    let maxScale: CGFloat = 5.0

    func resetView() {
        scale = 1.0
        offset = .zero
    }

    func togglePreview() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isPreviewVisible.toggle()
        }
    }
}
