import Foundation

/// Minimal parser for the original CLCL's CLCL.ini.
/// The Windows version writes UTF-16LE with BOM; UTF-8 and Shift_JIS
/// files are also accepted so a hand-edited file works too.
struct IniFile {
    private var sections: [String: [String: String]] = [:]

    init?(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let text = IniFile.decode(data) else { return nil }
        parse(text)
    }

    private static func decode(_ data: Data) -> String? {
        if data.count >= 2, data[0] == 0xFF, data[1] == 0xFE {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if data.count >= 3, data[0] == 0xEF, data[1] == 0xBB, data[2] == 0xBF {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if let s = String(data: data, encoding: .utf8) { return s }
        return String(data: data, encoding: .shiftJIS)
    }

    private mutating func parse(_ text: String) {
        var current = ""
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if line.hasPrefix("["), line.hasSuffix("]") {
                current = String(line.dropFirst().dropLast()).lowercased()
                if sections[current] == nil { sections[current] = [:] }
                continue
            }
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            sections[current, default: [:]][key] = value
        }
    }

    func string(_ section: String, _ key: String) -> String? {
        sections[section.lowercased()]?[key.lowercased()]
    }

    func int(_ section: String, _ key: String) -> Int? {
        string(section, key).flatMap { Int($0) }
    }
}
