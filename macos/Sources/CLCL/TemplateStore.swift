import AppKit

/// Templates (定型文) stored as plain files under
/// ~/Library/Application Support/CLCL/templates/ so they can be created and
/// edited directly in Finder or any text editor:
///
///   .txt → text template (UTF-8); the file name is the menu title
///   .png → image template
///   subfolders → submenus
///
/// The menu re-reads the folder every time it opens, so external edits show
/// up immediately. Items registered from the menu are written here too.
final class TemplateStore {
    enum Node {
        case item(title: String, url: URL)
        case folder(title: String, children: [Node])
    }

    let dir: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        dir = base.appendingPathComponent("CLCL/templates", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        migrateJSONIfNeeded()
    }

    var isEmpty: Bool { tree().isEmpty }

    func tree() -> [Node] { scan(dir) }

    private func scan(_ url: URL) -> [Node] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]) else { return [] }
        return entries
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .compactMap { entry in
                if (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                    return .folder(title: entry.lastPathComponent, children: scan(entry))
                }
                switch entry.pathExtension.lowercased() {
                case "txt":
                    return .item(title: entry.deletingPathExtension().lastPathComponent, url: entry)
                case "png":
                    return .item(title: "🖼 " + entry.deletingPathExtension().lastPathComponent, url: entry)
                default:
                    return nil
                }
            }
    }

    func load(_ url: URL) -> ClipItem? {
        switch url.pathExtension.lowercased() {
        case "txt":
            guard let s = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return ClipItem(text: s)
        case "png":
            guard let d = try? Data(contentsOf: url) else { return nil }
            return ClipItem(imagePNG: d)
        default:
            return nil
        }
    }

    @discardableResult
    func add(_ item: ClipItem) -> Bool {
        let name: String
        let ext: String
        let data: Data
        switch item.kind {
        case .text:
            guard let text = item.text, !text.isEmpty else { return false }
            name = TemplateStore.fileName(from: text)
            ext = "txt"
            data = Data(text.utf8)
        case .image:
            guard let png = item.imagePNG else { return false }
            name = "画像"
            ext = "png"
            data = png
        case .files:
            let text = (item.filePaths ?? []).joined(separator: "\n")
            guard !text.isEmpty else { return false }
            name = TemplateStore.fileName(from: text)
            ext = "txt"
            data = Data(text.utf8)
        }
        return (try? data.write(to: uniqueURL(name: name, ext: ext))) != nil
    }

    /// Move to the Trash rather than deleting outright.
    func remove(_ url: URL) {
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Menu title / file name from the first line of the text.
    private static func fileName(from text: String) -> String {
        var line = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first ?? ""
        line = line.replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
            .trimmingCharacters(in: .whitespaces)
        if line.count > 32 { line = String(line.prefix(32)) }
        return line.isEmpty ? "定型文" : line
    }

    private func uniqueURL(name: String, ext: String) -> URL {
        var url = dir.appendingPathComponent(name).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appendingPathComponent("\(name) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return url
    }

    /// One-time migration from the old templates.json.
    private func migrateJSONIfNeeded() {
        let json = dir.deletingLastPathComponent().appendingPathComponent("templates.json")
        guard let data = try? Data(contentsOf: json),
              let items = try? JSONDecoder().decode([ClipItem].self, from: data)
        else { return }
        for item in items {
            add(item)
        }
        try? FileManager.default.moveItem(
            at: json,
            to: json.appendingPathExtension("migrated"))
    }
}
