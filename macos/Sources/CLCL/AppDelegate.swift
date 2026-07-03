import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let store = HistoryStore()
    private var watcher: ClipboardWatcher!
    private var hotKey: HotKey!

    /// The app that was frontmost when the popup opened — paste target.
    private var pasteTarget: NSRunningApplication?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusItem.centered()
        statusItem.button?.title = "📋"
        statusItem.button?.toolTip = "CLCL for Mac"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        watcher = ClipboardWatcher { [weak self] item in
            self?.store.add(item)
        }
        watcher.start()

        // Option+C, mirroring the original Alt+C
        hotKey = HotKey { [weak self] in
            self?.showPopupMenu()
        }

        if !Paster.canPaste {
            Paster.requestPermission()
        }
    }

    // MARK: - Menus

    /// Status-bar menu is rebuilt each time it opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        pasteTarget = NSWorkspace.shared.frontmostApplication
        buildMenu(menu)
    }

    private func showPopupMenu() {
        pasteTarget = NSWorkspace.shared.frontmostApplication
        let menu = NSMenu()
        buildMenu(menu)
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // History
        if store.history.isEmpty {
            let empty = NSMenuItem(title: "(履歴なし)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for (i, item) in store.history.enumerated() {
            let mi = NSMenuItem(title: item.menuTitle,
                                action: #selector(selectHistoryItem(_:)),
                                keyEquivalent: i < 9 ? String(i + 1) : "")
            mi.keyEquivalentModifierMask = []
            mi.target = self
            mi.tag = i
            if let thumb = item.menuImage() {
                mi.image = thumb
            }
            if item.kind == .text, let text = item.text {
                mi.toolTip = String(text.prefix(1000))
            }
            menu.addItem(mi)
        }

        menu.addItem(.separator())

        // Templates (定型文)
        let templatesItem = NSMenuItem(title: "定型文", action: nil, keyEquivalent: "")
        let templatesMenu = NSMenu()
        if store.templates.isEmpty {
            let empty = NSMenuItem(title: "(未登録)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            templatesMenu.addItem(empty)
        }
        for (i, item) in store.templates.enumerated() {
            let mi = NSMenuItem(title: item.menuTitle,
                                action: #selector(selectTemplateItem(_:)),
                                keyEquivalent: "")
            mi.target = self
            mi.tag = i
            if let thumb = item.menuImage() { mi.image = thumb }
            templatesMenu.addItem(mi)
        }
        templatesMenu.addItem(.separator())
        let register = NSMenuItem(title: "現在のクリップボードを登録",
                                  action: #selector(registerTemplate),
                                  keyEquivalent: "")
        register.target = self
        templatesMenu.addItem(register)
        if !store.templates.isEmpty {
            let deleteMenu = NSMenu()
            for (i, item) in store.templates.enumerated() {
                let mi = NSMenuItem(title: item.menuTitle,
                                    action: #selector(deleteTemplateItem(_:)),
                                    keyEquivalent: "")
                mi.target = self
                mi.tag = i
                deleteMenu.addItem(mi)
            }
            let deleteItem = NSMenuItem(title: "定型文を削除", action: nil, keyEquivalent: "")
            deleteItem.submenu = deleteMenu
            templatesMenu.addItem(deleteItem)
        }
        templatesItem.submenu = templatesMenu
        menu.addItem(templatesItem)

        menu.addItem(.separator())

        let clear = NSMenuItem(title: "履歴をクリア", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        if !Paster.canPaste {
            let perm = NSMenuItem(title: "自動貼り付けを有効化(アクセシビリティ許可)…",
                                  action: #selector(requestAccessibility),
                                  keyEquivalent: "")
            perm.target = self
            menu.addItem(perm)
        }

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "CLCLを終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func selectHistoryItem(_ sender: NSMenuItem) {
        guard store.history.indices.contains(sender.tag) else { return }
        paste(store.history[sender.tag])
    }

    @objc private func selectTemplateItem(_ sender: NSMenuItem) {
        guard store.templates.indices.contains(sender.tag) else { return }
        paste(store.templates[sender.tag])
    }

    @objc private func deleteTemplateItem(_ sender: NSMenuItem) {
        store.removeTemplate(at: sender.tag)
    }

    @objc private func registerTemplate() {
        if let item = ClipItem.fromPasteboard(.general) {
            store.addTemplate(item)
        }
    }

    @objc private func clearHistory() {
        store.clearHistory()
    }

    @objc private func requestAccessibility() {
        Paster.requestPermission()
    }

    private func paste(_ item: ClipItem) {
        watcher.suppressNext = true
        item.writeToPasteboard(.general)
        // Selected history items move to the top, like the original.
        store.add(item)
        Paster.paste(into: pasteTarget)
    }
}

private extension NSStatusItem {
    static func centered() -> NSStatusItem {
        NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    }
}
