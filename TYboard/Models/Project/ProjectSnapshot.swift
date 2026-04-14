import Foundation
import PencilKit

/// A snapshot of the entire project state for version history
struct ProjectSnapshot: Identifiable, Codable {
    let id: UUID
    let version: Int
    let name: String
    let timestamp: Date
    let drawingData: Data
    let generatedHTML: String?
    let chatHistorySummary: String

    init(
        version: Int,
        name: String,
        drawing: PKDrawing,
        generatedHTML: String?,
        chatSummary: String
    ) {
        self.id = UUID()
        self.version = version
        self.name = name
        self.timestamp = Date()
        self.drawingData = drawing.dataRepresentation()
        self.generatedHTML = generatedHTML
        self.chatHistorySummary = chatSummary
    }

    var drawing: PKDrawing {
        (try? PKDrawing(data: drawingData)) ?? PKDrawing()
    }
}

/// Manages project snapshots
@Observable
final class SnapshotManager {
    var snapshots: [ProjectSnapshot] = []
    private var nextVersion = 1

    private var storageURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("snapshots.json")
    }

    init() {
        load()
    }

    func takeSnapshot(
        name: String,
        drawing: PKDrawing,
        generatedHTML: String?,
        chatSummary: String
    ) {
        let snapshot = ProjectSnapshot(
            version: nextVersion,
            name: name,
            drawing: drawing,
            generatedHTML: generatedHTML,
            chatSummary: chatSummary
        )
        snapshots.append(snapshot)
        nextVersion += 1
        save()
    }

    func deleteSnapshot(_ snapshot: ProjectSnapshot) {
        snapshots.removeAll { $0.id == snapshot.id }
        save()
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshots) {
            try? data.write(to: storageURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        snapshots = (try? decoder.decode([ProjectSnapshot].self, from: data)) ?? []
        nextVersion = (snapshots.map(\.version).max() ?? 0) + 1
    }
}
