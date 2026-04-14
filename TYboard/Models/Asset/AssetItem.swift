import Foundation
import UIKit

struct AssetItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var tags: [String]
    var type: AssetType
    var filePath: String
    var thumbnailPath: String?
    let createdAt: Date
    var fileSize: Int64

    enum AssetType: String, Codable, CaseIterable {
        case image = "image"
        case pdf = "pdf"
        case text = "text"
        case screenshot = "screenshot"
        case reference = "reference"

        var iconName: String {
            switch self {
            case .image: "photo"
            case .pdf: "doc.richtext"
            case .text: "doc.text"
            case .screenshot: "camera.viewfinder"
            case .reference: "link"
            }
        }

        var displayName: String {
            switch self {
            case .image: "图片"
            case .pdf: "PDF"
            case .text: "文本"
            case .screenshot: "截图"
            case .reference: "参考"
            }
        }
    }

    init(
        name: String,
        tags: [String] = [],
        type: AssetType,
        filePath: String,
        thumbnailPath: String? = nil,
        fileSize: Int64 = 0
    ) {
        self.id = UUID()
        self.name = name
        self.tags = tags
        self.type = type
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
        self.createdAt = Date()
        self.fileSize = fileSize
    }
}
