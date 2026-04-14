import Foundation

struct SlideData: Codable, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var notes: String
    var layout: SlideLayout
    var imageURL: String?
    var backgroundColor: String?

    enum SlideLayout: String, Codable, CaseIterable {
        case titleSlide = "title"
        case titleContent = "title-content"
        case twoColumn = "two-column"
        case imageLeft = "image-left"
        case imageRight = "image-right"
        case imageFull = "image-full"
        case blank = "blank"
    }

    init(
        title: String = "",
        content: String = "",
        notes: String = "",
        layout: SlideLayout = .titleContent,
        imageURL: String? = nil,
        backgroundColor: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.notes = notes
        self.layout = layout
        self.imageURL = imageURL
        self.backgroundColor = backgroundColor
    }
}

struct Presentation: Codable, Identifiable {
    let id: UUID
    var title: String
    var theme: PresentationTheme
    var slides: [SlideData]
    let createdAt: Date

    init(title: String = "未命名演示", theme: PresentationTheme = .modern, slides: [SlideData] = []) {
        self.id = UUID()
        self.title = title
        self.theme = theme
        self.slides = slides
        self.createdAt = Date()
    }
}

enum PresentationTheme: String, Codable, CaseIterable {
    case modern = "modern"
    case minimal = "minimal"
    case dark = "dark"
    case colorful = "colorful"

    var displayName: String {
        switch self {
        case .modern: "现代"
        case .minimal: "极简"
        case .dark: "深色"
        case .colorful: "多彩"
        }
    }
}
