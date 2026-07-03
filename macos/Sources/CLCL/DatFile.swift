import Foundation

/// Parser for the original CLCL's item files (history.dat / regist.dat and
/// dated backups). Format, per File.c file_file_to_item():
///
///   0x01  item start, then NUL-terminated fields, each omitted when the
///         cursor already sits on 0x02: title, modified (hex FILETIME),
///         window name, plugin string, plugin param, option
///   0x02  end of item header; format blocks follow
///   <block> = data size (ASCII decimal, NUL), then fields omitted when on
///         0x03: format name, plugin string, plugin param, option,
///         then 0x03 and `size` raw data bytes
///   0x04  folder (NUL-terminated title), children until 0x05
///
/// "TEXT" data is CP932, "UNICODE TEXT" is UTF-16LE, both NUL-terminated.
enum DatFile {
    static func read(url: URL) -> [ClipItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        var cursor = Cursor(buf: [UInt8](data))
        var items: [ClipItem] = []
        parse(&cursor, level: 0, into: &items)
        return items
    }

    private struct Cursor {
        let buf: [UInt8]
        var i = 0
        var atEnd: Bool { i >= buf.count }
        var byte: UInt8 { buf[i] }

        /// Read a NUL-terminated string's bytes and consume the NUL.
        mutating func cString() -> [UInt8] {
            var out: [UInt8] = []
            while !atEnd, buf[i] != 0 {
                out.append(buf[i])
                i += 1
            }
            if !atEnd { i += 1 }
            return out
        }

        /// Skip fields until `marker`, then consume it.
        mutating func skip(to marker: UInt8) {
            while !atEnd, buf[i] != marker { i += 1 }
            if !atEnd { i += 1 }
        }
    }

    private static func parse(_ c: inout Cursor, level: Int, into items: inout [ClipItem]) {
        while !c.atEnd {
            switch c.byte {
            case 0x5:
                c.i += 1
                if level > 0 { return }
            case 0x4:
                c.i += 1
                if !c.atEnd, c.byte != 0x2 { _ = c.cString() } // folder title
                while !c.atEnd, c.byte != 0x1, c.byte != 0x4, c.byte != 0x5 { c.i += 1 }
                parse(&c, level: level + 1, into: &items) // flatten folders
            case 0x1:
                c.i += 1
                // title, modified, window name, plugin string/param, option
                for _ in 0..<6 {
                    if !c.atEnd, c.byte != 0x2 { _ = c.cString() }
                }
                c.skip(to: 0x2)
                if let item = parseFormats(&c) {
                    items.append(item)
                }
            default:
                // Stray format block with no owning item (shouldn't happen).
                _ = readFormatBlock(&c)
            }
        }
    }

    /// Read this item's format blocks and pick the best-supported one.
    private static func parseFormats(_ c: inout Cursor) -> ClipItem? {
        var unicodeText: [UInt8]?
        var ansiText: [UInt8]?
        while !c.atEnd, c.byte != 0x1, c.byte != 0x4, c.byte != 0x5 {
            let (name, data) = readFormatBlock(&c)
            switch name.uppercased() {
            case "UNICODE TEXT": unicodeText = data
            case "TEXT", "OEM TEXT": ansiText = data
            default: break // BITMAP, DROP FILE LIST etc. not imported
            }
        }
        if let bytes = unicodeText, let s = decodeUTF16LE(bytes), !s.isEmpty {
            return ClipItem(text: s)
        }
        if let bytes = ansiText {
            let d = Data(bytes.prefix(while: { $0 != 0 }))
            if let s = String(data: d, encoding: .shiftJIS) ?? String(data: d, encoding: .utf8),
               !s.isEmpty {
                return ClipItem(text: s)
            }
        }
        return nil
    }

    private static func readFormatBlock(_ c: inout Cursor) -> (name: String, data: [UInt8]) {
        let sizeStr = String(decoding: c.cString(), as: UTF8.self)
        let size = Int(sizeStr) ?? 0
        var name = ""
        if !c.atEnd, c.byte != 0x3 {
            name = String(decoding: c.cString(), as: UTF8.self)
        }
        for _ in 0..<3 { // plugin string, plugin param, option
            if !c.atEnd, c.byte != 0x3 { _ = c.cString() }
        }
        c.skip(to: 0x3)
        let end = min(c.i + size, c.buf.count)
        let data = Array(c.buf[c.i..<end])
        c.i = end
        return (name, data)
    }

    private static func decodeUTF16LE(_ bytes: [UInt8]) -> String? {
        var b = bytes
        if b.count % 2 == 1 { b.removeLast() }
        // Drop the terminating NUL character(s).
        while b.count >= 2, b[b.count - 1] == 0, b[b.count - 2] == 0 {
            b.removeLast(2)
        }
        return String(bytes: b, encoding: .utf16LittleEndian)
    }
}
