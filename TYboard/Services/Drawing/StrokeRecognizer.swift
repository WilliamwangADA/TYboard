import Foundation
import PencilKit

/// Recognizes common shapes and gestures from PencilKit strokes
enum StrokeRecognizer {

    struct RecognizedShape {
        let type: ShapeType
        let bounds: CGRect
        let confidence: Double
    }

    enum ShapeType: String {
        case rectangle = "rectangle"
        case circle = "circle"
        case arrow = "arrow"
        case line = "line"
        case text = "text"
        case unknown = "unknown"

        var uiElementHint: String {
            switch self {
            case .rectangle: "容器/卡片/按钮/输入框"
            case .circle: "按钮/图标/头像"
            case .arrow: "导航/跳转/数据流向"
            case .line: "分割线/连接线"
            case .text: "标签/标题"
            case .unknown: "未识别"
            }
        }
    }

    /// Analyze all strokes in a drawing
    static func recognizeShapes(in drawing: PKDrawing) -> [RecognizedShape] {
        drawing.strokes.compactMap { recognizeStroke($0) }
    }

    /// Recognize a single stroke
    static func recognizeStroke(_ stroke: PKStroke) -> RecognizedShape? {
        let points = stroke.path.interpolatedPoints(by: .distance(5))
            .map { $0.location }
        guard points.count >= 3 else { return nil }

        let bounds = stroke.renderBounds

        // Check for rectangle
        if isRectangle(points: points, bounds: bounds) {
            return RecognizedShape(type: .rectangle, bounds: bounds, confidence: 0.8)
        }

        // Check for circle/ellipse
        if isCircle(points: points, bounds: bounds) {
            return RecognizedShape(type: .circle, bounds: bounds, confidence: 0.8)
        }

        // Check for arrow
        if isArrow(points: points) {
            return RecognizedShape(type: .arrow, bounds: bounds, confidence: 0.7)
        }

        // Check for straight line
        if isLine(points: points, bounds: bounds) {
            return RecognizedShape(type: .line, bounds: bounds, confidence: 0.9)
        }

        return RecognizedShape(type: .unknown, bounds: bounds, confidence: 0.3)
    }

    // MARK: - Shape detection heuristics

    private static func isRectangle(points: [CGPoint], bounds: CGRect) -> Bool {
        // Check if the stroke is roughly rectangular:
        // 1. Close to the bounding box
        // 2. Mostly axis-aligned segments
        // 3. Approximately closed
        guard points.count >= 8 else { return false }

        let first = points.first!
        let last = points.last!
        let closedDistance = hypot(last.x - first.x, last.y - first.y)
        let perimeter = 2 * (bounds.width + bounds.height)

        // Must be roughly closed
        guard closedDistance < perimeter * 0.15 else { return false }

        // Aspect ratio check - not too thin
        let aspectRatio = bounds.width / max(bounds.height, 1)
        guard aspectRatio > 0.2 && aspectRatio < 5.0 else { return false }

        // Check that most points are near the edges of the bounding box
        let margin = max(bounds.width, bounds.height) * 0.2
        let nearEdgeCount = points.filter { point in
            let nearLeft = abs(point.x - bounds.minX) < margin
            let nearRight = abs(point.x - bounds.maxX) < margin
            let nearTop = abs(point.y - bounds.minY) < margin
            let nearBottom = abs(point.y - bounds.maxY) < margin
            return nearLeft || nearRight || nearTop || nearBottom
        }.count

        return Double(nearEdgeCount) / Double(points.count) > 0.7
    }

    private static func isCircle(points: [CGPoint], bounds: CGRect) -> Bool {
        guard points.count >= 8 else { return false }

        let first = points.first!
        let last = points.last!
        let closedDistance = hypot(last.x - first.x, last.y - first.y)
        let diameter = max(bounds.width, bounds.height)

        // Must be roughly closed
        guard closedDistance < diameter * 0.3 else { return false }

        // Aspect ratio should be roughly 1:1
        let aspectRatio = bounds.width / max(bounds.height, 1)
        guard aspectRatio > 0.5 && aspectRatio < 2.0 else { return false }

        // Check that points are roughly equidistant from center
        let centerX = bounds.midX
        let centerY = bounds.midY
        let expectedRadius = diameter / 2

        let radiusVariance = points.map { point in
            let r = hypot(point.x - centerX, point.y - centerY)
            return abs(r - expectedRadius) / expectedRadius
        }

        let avgVariance = radiusVariance.reduce(0, +) / Double(radiusVariance.count)
        return avgVariance < 0.3
    }

    private static func isArrow(points: [CGPoint]) -> Bool {
        guard points.count >= 5 else { return false }

        // An arrow typically has a long shaft and a short fork at the end
        // Simple heuristic: check if there's a direction change near the end
        let totalPoints = points.count
        let shaftEnd = Int(Double(totalPoints) * 0.7)

        // Check shaft is roughly straight
        let shaftPoints = Array(points[0..<shaftEnd])
        guard isRoughlyLinear(shaftPoints) else { return false }

        // Check there are direction changes near the end (arrowhead)
        let headPoints = Array(points[shaftEnd...])
        let directionChanges = countDirectionChanges(headPoints)

        return directionChanges >= 1
    }

    private static func isLine(points: [CGPoint], bounds: CGRect) -> Bool {
        guard points.count >= 3 else { return false }

        // Must not be closed
        let first = points.first!
        let last = points.last!
        let length = hypot(last.x - first.x, last.y - first.y)
        guard length > 20 else { return false }

        return isRoughlyLinear(points)
    }

    private static func isRoughlyLinear(_ points: [CGPoint]) -> Bool {
        guard let first = points.first, let last = points.last else { return false }

        let lineLength = hypot(last.x - first.x, last.y - first.y)
        guard lineLength > 0 else { return false }

        // Calculate max perpendicular distance from the line
        let dy: CGFloat = last.y - first.y
        let dx: CGFloat = last.x - first.x
        let c: CGFloat = last.x * first.y - last.y * first.x
        let maxDistance: CGFloat = points.map { point in
            let d = abs(dy * point.x - dx * point.y + c)
            return d / lineLength
        }.max() ?? 0

        return maxDistance < lineLength * 0.15
    }

    private static func countDirectionChanges(_ points: [CGPoint]) -> Int {
        guard points.count >= 3 else { return 0 }

        var changes = 0
        for i in 1..<(points.count - 1) {
            let dx1 = points[i].x - points[i-1].x
            let dy1 = points[i].y - points[i-1].y
            let dx2 = points[i+1].x - points[i].x
            let dy2 = points[i+1].y - points[i].y

            let cross = dx1 * dy2 - dy1 * dx2
            if abs(cross) > 100 {
                changes += 1
            }
        }
        return changes
    }
}
