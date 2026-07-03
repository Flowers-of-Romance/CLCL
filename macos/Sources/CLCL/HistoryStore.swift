import Foundation

/// Persists clipboard history as JSON under ~/Library/Application Support/CLCL/.
/// Templates (定型文) live in TemplateStore as plain files.
final class HistoryStore {
    private(set) var history: [ClipItem] = []

    var maxHistory: Int { Settings.shared.maxHistory }

    private let dir: URL
    private var historyFile: URL { dir.appendingPathComponent("history.json") }

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

    private func load() {
        if let data = try? Data(contentsOf: historyFile),
           let items = try? JSONDecoder().decode([ClipItem].self, from: data) {
            history = items
        }
    }

    private func save() {
        guard Settings.shared.saveHistory else { return }
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyFile, options: .atomic)
        }
    }
}
