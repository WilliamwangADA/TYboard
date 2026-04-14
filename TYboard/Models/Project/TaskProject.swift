import Foundation
import PencilKit

/// Represents a single user task/project
struct TaskProject: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var type: TaskType
    var status: TaskStatus
    var folderPath: String
    let createdAt: Date
    var updatedAt: Date
    var drawingData: Data
    var generatedHTML: String?
    var chatHistory: [ChatMessageData]

    enum TaskType: String, Codable, CaseIterable {
        case webApp = "Web应用"
        case game = "小游戏"
        case app = "App"
        case ppt = "PPT"
        case animationScript = "动画脚本"
        case storyboard = "分镜头"
        case comic = "漫画"
        case videoScript = "视频脚本"
        case landingPage = "落地页"
        case dashboard = "仪表盘"
        case other = "其他"

        var iconName: String {
            switch self {
            case .webApp: "globe"
            case .game: "gamecontroller"
            case .app: "apps.iphone"
            case .ppt: "rectangle.on.rectangle.angled"
            case .animationScript: "film"
            case .storyboard: "square.split.2x2"
            case .comic: "book"
            case .videoScript: "video"
            case .landingPage: "doc.richtext"
            case .dashboard: "chart.bar"
            case .other: "star"
            }
        }
    }

    enum TaskStatus: String, Codable {
        case active = "进行中"
        case paused = "暂停"
        case completed = "已完成"
    }

    /// Serializable chat message for persistence
    struct ChatMessageData: Codable, Equatable {
        let role: String
        let content: String
        let timestamp: Date
    }

    init(name: String, type: TaskType) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.status = .active
        self.folderPath = id.uuidString
        self.createdAt = Date()
        self.updatedAt = Date()
        self.drawingData = PKDrawing().dataRepresentation()
        self.generatedHTML = nil
        self.chatHistory = []
    }

    var drawing: PKDrawing {
        get { (try? PKDrawing(data: drawingData)) ?? PKDrawing() }
        set { drawingData = newValue.dataRepresentation() }
    }

    static func == (lhs: TaskProject, rhs: TaskProject) -> Bool {
        lhs.id == rhs.id
    }
}
