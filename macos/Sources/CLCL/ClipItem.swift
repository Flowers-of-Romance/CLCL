import AppKit

/// A single clipboard entry. Text and images are supported;
/// file lists are stored as their paths (text-like).
struct ClipItem: Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case image
        case files
    }

    let id: UUID
    let kind: Kind
    var text: String?
    var imagePNG: Data?
    var filePaths: [String]?
    let date: Date

    init(text: String) {
        self.id = UUID()
        self.kind = .text
        self.text = text
        self.imagePNG = nil
        self.filePaths = nil
        self.date = Date()
    }

    init(imagePNG: Data) {
        self.id = UUID()
        self.kind = .image
        self.text = nil
        self.imagePNG = imagePNG
        self.filePaths = nil
        self.date = Date()
    }

    init(filePaths: [String]) {
        self.id = UUID()
        self.kind = .files
        self.text = nil
        self.imagePNG = nil
        self.filePaths = filePaths
        self.date = Date()
    }

    static func == (lhs: ClipItem, rhs: ClipItem) -> Bool {
        guard lhs.kind == rhs.kind else { return false }
        switch lhs.kind {
        case .text: return lhs.text == rhs.text
        case .image: return lhs.imagePNG == rhs.imagePNG
        case .files: return lhs.filePaths == rhs.filePaths
        }
    }

    /// Menu title: first line of text, truncated.
    var menuTitle: String {
        switch kind {
        case .text:
            let line = (text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .newlines)
                .first ?? ""
            return line.count > 40 ? String(line.prefix(40)) + "…" : (line.isEmpty ? "(空白)" : line)
        case .image:
            return "🖼 画像"
        case .files:
            let paths = filePaths ?? []
            let first = (paths.first as NSString?)?.lastPathComponent ?? ""
            return paths.count > 1 ? "📄 \(first) 他\(paths.count - 1)件" : "📄 \(first)"
        }
    }

    /// Thumbnail for image items, shown in the menu like the original CLCL.
    func menuImage(maxSize: CGFloat = 80) -> NSImage? {
        guard kind == .image, let data = imagePNG, let img = NSImage(data: data) else { return nil }
        let size = img.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxSize / size.width, maxSize / size.height, 1)
        let thumb = NSImage(size: NSSize(width: size.width * scale, height: size.height * scale))
        thumb.lockFocus()
        img.draw(in: NSRect(origin: .zero, size: thumb.size))
        thumb.unlockFocus()
        return thumb
    }

    /// Write this item back to the pasteboard.
    func writeToPasteboard(_ pb: NSPasteboard) {
        pb.clearContents()
        switch kind {
        case .text:
            pb.setString(text ?? "", forType: .string)
        case .image:
            if let data = imagePNG {
                pb.setData(data, forType: .png)
                if let img = NSImage(data: data), let tiff = img.tiffRepresentation {
                    pb.setData(tiff, forType: .tiff)
                }
            }
        case .files:
            let urls = (filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            pb.writeObjects(urls)
        }
    }

    /// Read the current pasteboard into a ClipItem, if it holds a supported format.
    static func fromPasteboard(_ pb: NSPasteboard) -> ClipItem? {
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return ClipItem(filePaths: urls.map(\.path))
        }
        if let str = pb.string(forType: .string), !str.isEmpty {
            return ClipItem(text: str)
        }
        if let png = pb.data(forType: .png) {
            return ClipItem(imagePNG: png)
        }
        if let tiff = pb.data(forType: .tiff),
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return ClipItem(imagePNG: png)
        }
        return nil
    }
}
