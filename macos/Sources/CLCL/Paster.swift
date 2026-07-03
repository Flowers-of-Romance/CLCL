import AppKit

/// Auto-paste: re-activate the app that was frontmost, then synthesize Cmd+V.
/// Requires the Accessibility permission; without it we just leave the item
/// on the pasteboard for a manual paste.
enum Paster {
    static var canPaste: Bool {
        AXIsProcessTrusted()
    }

    /// Ask the user for the Accessibility permission (shows the system prompt once).
    static func requestPermission() {
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    static func paste(into app: NSRunningApplication?) {
        guard canPaste else { return }
        app?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            sendCmdV()
        }
    }

    private static func sendCmdV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(9) // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
