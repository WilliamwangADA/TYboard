import SwiftUI
import PencilKit

@Observable
final class CanvasState {
    var scale: CGFloat = 1.0
    var offset: CGPoint = .zero
    var drawing: PKDrawing = PKDrawing()
    var isPreviewVisible: Bool = true
    var previewWidthRatio: CGFloat = 1.0 / 3.0
    var canvasBackground: CanvasBackground = .grid

    enum CanvasBackground: String, CaseIterable {
        case white = "全白"
        case grid = "网格"
        case dots = "点阵"
        case blackboard = "黑板"

        var bgColor: UIColor {
            switch self {
            case .white: .systemBackground
            case .grid: .systemBackground
            case .dots: .systemBackground
            case .blackboard: UIColor(red: 0.15, green: 0.2, blue: 0.15, alpha: 1.0)
            }
        }

        var lineColor: UIColor {
            switch self {
            case .white: .clear
            case .grid: .separator.withAlphaComponent(0.3)
            case .dots: .separator.withAlphaComponent(0.4)
            case .blackboard: UIColor.white.withAlphaComponent(0.08)
            }
        }

        var iconName: String {
            switch self {
            case .white: "rectangle"
            case .grid: "grid"
            case .dots: "circle.grid.3x3"
            case .blackboard: "rectangle.fill"
            }
        }
    }

    // Drawing tools
    var selectedTool: DrawingTool = .pen
    var selectedColor: Color = .black
    var lineWidth: CGFloat = 3.0

    // Computed PKTool for the canvas
    var currentPKTool: PKTool {
        selectedTool.pkTool(color: UIColor(selectedColor), width: lineWidth)
    }

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
