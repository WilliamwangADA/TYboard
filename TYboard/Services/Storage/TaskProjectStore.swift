import Foundation
import PencilKit

/// Manages multiple task projects with persistence
@Observable
final class TaskProjectStore {
    var projects: [TaskProject] = []
    var currentProjectId: UUID?

    var currentProject: TaskProject? {
        get { projects.first(where: { $0.id == currentProjectId }) }
        set {
            if let newValue, let index = projects.firstIndex(where: { $0.id == newValue.id }) {
                projects[index] = newValue
                save()
            }
        }
    }

    var activeProjects: [TaskProject] {
        projects.filter { $0.status == .active }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var allProjectsSorted: [TaskProject] {
        projects.sorted { $0.updatedAt > $1.updatedAt }
    }

    private let fileManager = FileManager.default
    private var storageURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Projects", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var manifestURL: URL {
        storageURL.appendingPathComponent("projects.json")
    }

    init() {
        load()
    }

    // MARK: - CRUD

    func createProject(name: String, type: TaskProject.TaskType) -> TaskProject {
        var project = TaskProject(name: name, type: type)

        // Create project folder
        let projectDir = storageURL.appendingPathComponent(project.folderPath, isDirectory: true)
        try? fileManager.createDirectory(at: projectDir, withIntermediateDirectories: true)

        projects.append(project)
        currentProjectId = project.id
        save()
        return project
    }

    func switchTo(_ project: TaskProject) {
        // Save current project state first
        saveCurrentState()
        currentProjectId = project.id
    }

    func deleteProject(_ project: TaskProject) {
        // Remove folder
        let projectDir = storageURL.appendingPathComponent(project.folderPath)
        try? fileManager.removeItem(at: projectDir)

        projects.removeAll { $0.id == project.id }
        if currentProjectId == project.id {
            currentProjectId = projects.first?.id
        }
        save()
    }

    func updateProjectStatus(_ project: TaskProject, status: TaskProject.TaskStatus) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].status = status
            projects[index].updatedAt = Date()
            save()
        }
    }

    // MARK: - Save/Load current state

    func saveCurrentState(drawing: PKDrawing? = nil, generatedHTML: String? = nil, messages: [ChatMessage]? = nil) {
        guard let id = currentProjectId,
              let index = projects.firstIndex(where: { $0.id == id }) else { return }

        if let drawing {
            projects[index].drawingData = drawing.dataRepresentation()
        }
        if let html = generatedHTML {
            projects[index].generatedHTML = html
        }
        if let messages {
            projects[index].chatHistory = messages.map {
                TaskProject.ChatMessageData(role: $0.role.rawValue, content: $0.content, timestamp: $0.timestamp)
            }
        }
        projects[index].updatedAt = Date()
        save()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(projects) {
            try? data.write(to: manifestURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: manifestURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        projects = (try? decoder.decode([TaskProject].self, from: data)) ?? []
        currentProjectId = projects.first(where: { $0.status == .active })?.id ?? projects.first?.id
    }
}
