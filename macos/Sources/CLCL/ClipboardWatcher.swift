import AppKit

/// macOS has no clipboard-change notification, so poll NSPasteboard.changeCount.
final class ClipboardWatcher {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let onChange: (ClipItem) -> Void

    /// Set while CLCL itself writes to the pasteboard, to avoid re-capturing.
    var suppressNext = false

    init(onChange: @escaping (ClipItem) -> Void) {
        self.onChange = onChange
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start(interval: TimeInterval = 0.4) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount
        if suppressNext {
            suppressNext = false
            return
        }
        if let item = ClipItem.fromPasteboard(pb) {
            onChange(item)
        }
    }
}
