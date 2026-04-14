import Foundation
import PencilKit

/// Tracks and learns from user's drawing habits to improve recognition
@Observable
final class UserHabitTracker {
    var preferredPenColor: String = "#000000"
    var preferredPenWidth: CGFloat = 3.0
    var preferredTool: String = "pen"
    var averageStrokeSpeed: Double = 0
    var totalStrokes: Int = 0

    // Shape usage frequency
    var shapeFrequency: [String: Int] = [:]

    private let defaults = UserDefaults.standard
    private let storageKey = "user_drawing_habits"

    init() {
        load()
    }

    /// Record a drawing session
    func recordStroke(_ stroke: PKStroke) {
        totalStrokes += 1

        // Track tool preference
        preferredTool = stroke.ink.inkType.rawValue

        save()
    }

    /// Record shape recognition result
    func recordShapeUsage(_ shapeType: StrokeRecognizer.ShapeType) {
        let key = shapeType.rawValue
        shapeFrequency[key, default: 0] += 1
        save()
    }

    /// Get the most commonly drawn shapes
    var topShapes: [(String, Int)] {
        shapeFrequency.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    /// Generate a habit summary for AI context
    func habitSummary() -> String {
        var summary = "用户绘图习惯："
        summary += "\n- 总笔画数: \(totalStrokes)"
        summary += "\n- 常用工具: \(preferredTool)"

        if !shapeFrequency.isEmpty {
            let top = topShapes.map { "\($0.0)(\($0.1)次)" }.joined(separator: "、")
            summary += "\n- 常用形状: \(top)"
        }

        return summary
    }

    // MARK: - Persistence

    private func save() {
        let data: [String: Any] = [
            "preferredPenColor": preferredPenColor,
            "preferredPenWidth": preferredPenWidth,
            "preferredTool": preferredTool,
            "averageStrokeSpeed": averageStrokeSpeed,
            "totalStrokes": totalStrokes,
            "shapeFrequency": shapeFrequency,
        ]
        defaults.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = defaults.dictionary(forKey: storageKey) else { return }
        preferredPenColor = data["preferredPenColor"] as? String ?? "#000000"
        preferredPenWidth = data["preferredPenWidth"] as? CGFloat ?? 3.0
        preferredTool = data["preferredTool"] as? String ?? "pen"
        averageStrokeSpeed = data["averageStrokeSpeed"] as? Double ?? 0
        totalStrokes = data["totalStrokes"] as? Int ?? 0
        shapeFrequency = data["shapeFrequency"] as? [String: Int] ?? [:]
    }
}
