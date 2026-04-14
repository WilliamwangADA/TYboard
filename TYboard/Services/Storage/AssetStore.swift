import Foundation
import UIKit

@Observable
final class AssetStore {
    var assets: [AssetItem] = []
    var selectedTags: Set<String> = []
    var searchQuery: String = ""

    private let fileManager = FileManager.default
    private var assetsDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Assets", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var thumbnailsDirectory: URL {
        let dir = assetsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var manifestURL: URL {
        assetsDirectory.appendingPathComponent("manifest.json")
    }

    init() {
        loadManifest()
    }

    // MARK: - Filtered assets

    var filteredAssets: [AssetItem] {
        var result = assets

        if !searchQuery.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchQuery) })
            }
        }

        if !selectedTags.isEmpty {
            result = result.filter { asset in
                !selectedTags.isDisjoint(with: Set(asset.tags))
            }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    var allTags: [String] {
        Array(Set(assets.flatMap(\.tags))).sorted()
    }

    // MARK: - Import

    /// Import image data
    func importImage(_ data: Data, name: String, tags: [String] = []) -> AssetItem? {
        let fileName = "\(UUID().uuidString).png"
        let filePath = assetsDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: filePath)

            // Generate thumbnail
            let thumbnailName = "thumb_\(fileName)"
            let thumbnailPath = thumbnailsDirectory.appendingPathComponent(thumbnailName)
            if let image = UIImage(data: data),
               let thumbnail = generateThumbnail(image, size: CGSize(width: 200, height: 200)),
               let thumbData = thumbnail.pngData() {
                try thumbData.write(to: thumbnailPath)
            }

            let asset = AssetItem(
                name: name,
                tags: tags,
                type: .image,
                filePath: fileName,
                thumbnailPath: thumbnailName,
                fileSize: Int64(data.count)
            )
            assets.append(asset)
            saveManifest()
            return asset
        } catch {
            return nil
        }
    }

    /// Import file from URL
    func importFile(from url: URL, tags: [String] = []) -> AssetItem? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let fileName = "\(UUID().uuidString)_\(url.lastPathComponent)"
        let destPath = assetsDirectory.appendingPathComponent(fileName)

        do {
            try fileManager.copyItem(at: url, to: destPath)
            let attrs = try fileManager.attributesOfItem(atPath: destPath.path)
            let fileSize = attrs[.size] as? Int64 ?? 0

            let type: AssetItem.AssetType
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "png", "jpg", "jpeg", "gif", "webp", "heic":
                type = .image
            case "pdf":
                type = .pdf
            case "txt", "md", "json", "html", "css", "js":
                type = .text
            default:
                type = .image
            }

            // Generate thumbnail for images
            var thumbnailName: String?
            if type == .image, let data = try? Data(contentsOf: destPath),
               let image = UIImage(data: data),
               let thumbnail = generateThumbnail(image, size: CGSize(width: 200, height: 200)),
               let thumbData = thumbnail.pngData() {
                thumbnailName = "thumb_\(fileName).png"
                try thumbData.write(to: thumbnailsDirectory.appendingPathComponent(thumbnailName!))
            }

            let asset = AssetItem(
                name: url.deletingPathExtension().lastPathComponent,
                tags: tags,
                type: type,
                filePath: fileName,
                thumbnailPath: thumbnailName,
                fileSize: fileSize
            )
            assets.append(asset)
            saveManifest()
            return asset
        } catch {
            return nil
        }
    }

    /// Batch import multiple files
    func importFiles(from urls: [URL], tags: [String] = []) -> [AssetItem] {
        urls.compactMap { importFile(from: $0, tags: tags) }
    }

    /// Add a reference (URL/product name)
    func addReference(name: String, url: String, tags: [String] = []) -> AssetItem {
        let fileName = "\(UUID().uuidString).ref.txt"
        let filePath = assetsDirectory.appendingPathComponent(fileName)
        try? url.write(to: filePath, atomically: true, encoding: .utf8)

        let asset = AssetItem(
            name: name,
            tags: tags + ["参考"],
            type: .reference,
            filePath: fileName,
            fileSize: Int64(url.count)
        )
        assets.append(asset)
        saveManifest()
        return asset
    }

    // MARK: - Delete

    func deleteAsset(_ asset: AssetItem) {
        let filePath = assetsDirectory.appendingPathComponent(asset.filePath)
        try? fileManager.removeItem(at: filePath)

        if let thumbName = asset.thumbnailPath {
            let thumbPath = thumbnailsDirectory.appendingPathComponent(thumbName)
            try? fileManager.removeItem(at: thumbPath)
        }

        assets.removeAll { $0.id == asset.id }
        saveManifest()
    }

    // MARK: - Update tags

    func updateTags(for assetId: UUID, tags: [String]) {
        if let index = assets.firstIndex(where: { $0.id == assetId }) {
            assets[index].tags = tags
            saveManifest()
        }
    }

    // MARK: - Get full path

    func fullPath(for asset: AssetItem) -> URL {
        assetsDirectory.appendingPathComponent(asset.filePath)
    }

    func thumbnailURL(for asset: AssetItem) -> URL? {
        guard let thumbName = asset.thumbnailPath else { return nil }
        return thumbnailsDirectory.appendingPathComponent(thumbName)
    }

    func imageData(for asset: AssetItem) -> Data? {
        try? Data(contentsOf: fullPath(for: asset))
    }

    // MARK: - Persistence

    private func saveManifest() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(assets) {
            try? data.write(to: manifestURL)
        }
    }

    private func loadManifest() {
        guard let data = try? Data(contentsOf: manifestURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        assets = (try? decoder.decode([AssetItem].self, from: data)) ?? []
    }

    // MARK: - Helpers

    private func generateThumbnail(_ image: UIImage, size: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            let aspectRatio = image.size.width / image.size.height
            var drawRect: CGRect
            if aspectRatio > 1 {
                let height = size.width / aspectRatio
                drawRect = CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
            } else {
                let width = size.height * aspectRatio
                drawRect = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
            }
            image.draw(in: drawRect)
        }
    }
}
