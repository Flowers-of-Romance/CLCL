import AppKit
import Carbon.HIToolbox

/// Settings, loaded from the original CLCL's CLCL.ini when present at
/// ~/Library/Application Support/CLCL/CLCL.ini — drop in the file from a
/// Windows install and the shared options carry over.
///
/// Imported keys:
///   [history] max, save, overlap_check
///   [main]    clipboard_watch
///   [menu]    bitmap_width, bitmap_height, show_tooltip
///   [action]  cnt, type-N, action-N, enable-N, modifiers-N, virtkey-N
///             (first enabled popup-menu hotkey; Alt→⌥, Ctrl→⌃, Shift→⇧, Win→⌘)
/// Everything else in the ini is Windows-specific and ignored.
final class Settings {
    static let shared = Settings()

    var maxHistory = 30
    var saveHistory = true
    var overlapCheck = true
    var watchClipboard = true
    var thumbWidth: CGFloat = 80
    var thumbHeight: CGFloat = 80
    var showTooltip = true
    struct HotKeySpec {
        let modifiers: UInt32
        let keyCode: UInt32
        let label: String
    }

    /// Popup hotkeys; the original allows several ([action] entries).
    var hotKeys = [HotKeySpec(modifiers: UInt32(optionKey),
                              keyCode: UInt32(kVK_ANSI_C),
                              label: "⌥C")]
    var hotKeyLabel: String { hotKeys.map(\.label).joined(separator: " / ") }
    /// Non-nil when an ini file was found and loaded.
    private(set) var iniURL: URL?

    // Windows hotkey modifier flags (winuser.h)
    private static let MOD_ALT = 0x1, MOD_CONTROL = 0x2, MOD_SHIFT = 0x4, MOD_WIN = 0x8

    private init() {
        // Fallback kept from the pre-ini versions.
        let v = UserDefaults.standard.integer(forKey: "maxHistory")
        if v > 0 { maxHistory = v }
        loadIni()
    }

    private func loadIni() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        let url = base.appendingPathComponent("CLCL/CLCL.ini")
        guard let ini = IniFile(url: url) else { return }
        iniURL = url

        if let v = ini.int("history", "max"), v > 0 { maxHistory = v }
        if let v = ini.int("history", "save") { saveHistory = v != 0 }
        if let v = ini.int("history", "overlap_check") { overlapCheck = v != 0 }
        if let v = ini.int("main", "clipboard_watch") { watchClipboard = v != 0 }
        if let v = ini.int("menu", "bitmap_width"), v > 0 { thumbWidth = CGFloat(v) }
        if let v = ini.int("menu", "bitmap_height"), v > 0 { thumbHeight = CGFloat(v) }
        if let v = ini.int("menu", "show_tooltip") { showTooltip = v != 0 }
        loadHotkey(ini)
    }

    /// Collect all enabled popup-menu hotkeys from [action]
    /// (action-N == ACTION_POPUPMEMU(0), type-N == ACTION_TYPE_HOTKEY(0)).
    private func loadHotkey(_ ini: IniFile) {
        guard let cnt = ini.int("action", "cnt"), cnt > 0 else { return }
        var found: [HotKeySpec] = []
        for i in 0..<cnt {
            guard ini.int("action", "action-\(i)") == 0,
                  ini.int("action", "type-\(i)") == 0,
                  ini.int("action", "enable-\(i)") ?? 1 != 0,
                  let vk = ini.int("action", "virtkey-\(i)"), vk != 0,
                  let key = Settings.keyCode(fromWindowsVK: vk)
            else { continue }

            let mods = ini.int("action", "modifiers-\(i)") ?? 0
            var carbon: UInt32 = 0
            var label = ""
            if mods & Settings.MOD_CONTROL != 0 { carbon |= UInt32(controlKey); label += "⌃" }
            if mods & Settings.MOD_ALT != 0 { carbon |= UInt32(optionKey); label += "⌥" }
            if mods & Settings.MOD_SHIFT != 0 { carbon |= UInt32(shiftKey); label += "⇧" }
            if mods & Settings.MOD_WIN != 0 { carbon |= UInt32(cmdKey); label += "⌘" }
            guard carbon != 0 else { continue } // unmodified keys would swallow normal typing

            found.append(HotKeySpec(modifiers: carbon, keyCode: key,
                                    label: label + String(UnicodeScalar(UInt8(vk)))))
        }
        if !found.isEmpty { hotKeys = found }
    }

    /// Windows virtual-key code (= ASCII for A-Z/0-9) to Carbon key code.
    private static func keyCode(fromWindowsVK vk: Int) -> UInt32? {
        let letters: [Character: Int] = [
            "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
            "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
            "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
            "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
            "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
            "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
            "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        ]
        guard let scalar = UnicodeScalar(UInt32(vk)), let code = letters[Character(scalar)] else {
            return nil
        }
        return UInt32(code)
    }
}
