import Foundation

/// Persists clipboard history and templates (定型文) as JSON under
/// ~/Library/Application Support/CLCL/.
final class HistoryStore {
    private(set) var history: [ClipItem] = []
    private(set) var templates: [ClipItem] = []

    var maxHistory: Int { Settings.shared.maxHistory }

    private let dir: URL
    private var historyFile: URL { dir.appendingPathComponent("history.json") }
    private var templatesFile: URL { dir.appendingPathComponent("templates.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        dir = base.appendingPathComponent("CLCL", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
    }

    func add(_ item: ClipItem) {
        if Settings.shared.overlapCheck {
            history.removeAll { $0 == item }
        }
        history.insert(item, at: 0)
        if history.count > maxHistory {
            history.removeLast(history.count - maxHistory)
        }
        save()
    }

    func clearHistory() {
        history.removeAll()
        save()
    }

    func addTemplate(_ item: ClipItem) {
        templates.removeAll { $0 == item }
        templates.append(item)
        save()
    }

    func removeTemplate(at index: Int) {
        guard templates.indices.contains(index) else { return }
        templates.remove(at: index)
        save()
    }

    private func load() {
        let decoder = JSONDecoder()
        if let data = try? Data(contentsOf: historyFile),
           let items = try? decoder.decode([ClipItem].self, from: data) {
            history = items
        }
        if let data = try? Data(contentsOf: templatesFile),
           let items = try? decoder.decode([ClipItem].self, from: data) {
            templates = items
        }
    }

    private func save() {
        let encoder = JSONEncoder()
        if Settings.shared.saveHistory, let data = try? encoder.encode(history) {
            try? data.write(to: historyFile, options: .atomic)
        }
        if let data = try? encoder.encode(templates) {
            try? data.write(to: templatesFile, options: .atomic)
        }
    }
}
