import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let store = HistoryStore()
    private let templates = TemplateStore()
    private var watcher: ClipboardWatcher!
    private var hotKeys: [HotKey] = []

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
        if Settings.shared.watchClipboard {
            watcher.start()
        }

        // Default ⌥C (mirroring the original Alt+C), overridable via CLCL.ini
        hotKeys = Settings.shared.hotKeys.map { spec in
            HotKey(keyCode: spec.keyCode, modifiers: spec.modifiers) { [weak self] in
                self?.showPopupMenu()
            }
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
            if Settings.shared.showTooltip, item.kind == .text, let text = item.text {
                mi.toolTip = String(text.prefix(1000))
            }
            menu.addItem(mi)
        }

        menu.addItem(.separator())

        // Templates (定型文) — read live from the templates folder
        let templatesItem = NSMenuItem(title: "定型文", action: nil, keyEquivalent: "")
        templatesItem.submenu = buildTemplatesMenu()
        menu.addItem(templatesItem)

        menu.addItem(.separator())

        let clear = NSMenuItem(title: "履歴をクリア", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)

        let iniState = Settings.shared.iniURL != nil
            ? "CLCL.ini 読み込み済み(ホットキー: \(Settings.shared.hotKeyLabel))"
            : "CLCL.ini 未検出(⌥C・デフォルト設定)"
        let ini = NSMenuItem(title: iniState, action: #selector(openIniFolder), keyEquivalent: "")
        ini.target = self
        menu.addItem(ini)

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

    private func buildTemplatesMenu() -> NSMenu {
        let menu = NSMenu()
        let tree = templates.tree()
        if tree.isEmpty {
            let empty = NSMenuItem(title: "(未登録)", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            addTemplateNodes(tree, to: menu)
        }
        menu.addItem(.separator())
        let register = NSMenuItem(title: "現在のクリップボードを登録",
                                  action: #selector(registerTemplate),
                                  keyEquivalent: "")
        register.target = self
        menu.addItem(register)
        let openFolder = NSMenuItem(title: "定型文フォルダを開く(テキストで編集)",
                                    action: #selector(openTemplatesFolder),
                                    keyEquivalent: "")
        openFolder.target = self
        menu.addItem(openFolder)
        let importDat = NSMenuItem(title: "Windowsの.datファイルからインポート…",
                                   action: #selector(importDatFile),
                                   keyEquivalent: "")
        importDat.target = self
        menu.addItem(importDat)
        if !tree.isEmpty {
            let deleteMenu = NSMenu()
            addTemplateNodes(tree, to: deleteMenu, deleting: true)
            let deleteItem = NSMenuItem(title: "定型文を削除(ゴミ箱へ)", action: nil, keyEquivalent: "")
            deleteItem.submenu = deleteMenu
            menu.addItem(deleteItem)
        }
        return menu
    }

    /// Folders become submenus; leaf items carry their file URL.
    private func addTemplateNodes(_ nodes: [TemplateStore.Node], to menu: NSMenu,
                                  deleting: Bool = false) {
        for node in nodes {
            switch node {
            case .folder(let title, let children):
                let mi = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let sub = NSMenu()
                addTemplateNodes(children, to: sub, deleting: deleting)
                mi.submenu = sub
                menu.addItem(mi)
            case .item(let title, let url):
                let mi = NSMenuItem(title: title,
                                    action: deleting ? #selector(deleteTemplateItem(_:))
                                                     : #selector(selectTemplateItem(_:)),
                                    keyEquivalent: "")
                mi.target = self
                mi.representedObject = url
                if Settings.shared.showTooltip, url.pathExtension.lowercased() == "txt",
                   let text = try? String(contentsOf: url, encoding: .utf8) {
                    mi.toolTip = String(text.prefix(1000))
                }
                menu.addItem(mi)
            }
        }
    }

    // MARK: - Actions

    @objc private func selectHistoryItem(_ sender: NSMenuItem) {
        guard store.history.indices.contains(sender.tag) else { return }
        paste(store.history[sender.tag])
    }

    @objc private func selectTemplateItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL,
              let item = templates.load(url) else { return }
        paste(item)
    }

    @objc private func deleteTemplateItem(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        templates.remove(url)
    }

    @objc private func registerTemplate() {
        if let item = ClipItem.fromPasteboard(.general) {
            templates.add(item)
        }
    }

    @objc private func openTemplatesFolder() {
        NSWorkspace.shared.open(templates.dir)
    }

    @objc private func clearHistory() {
        store.clearHistory()
    }

    @objc private func requestAccessibility() {
        Paster.requestPermission()
    }

    /// Import items from an original CLCL data file (history.dat / regist.dat
    /// or a dated backup) into the templates.
    @objc private func importDatFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "CLCLのdatファイル(history.dat / regist.dat / バックアップ)を選択"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let items = DatFile.read(url: url)
        for item in items {
            templates.add(item)
        }
        let alert = NSAlert()
        alert.messageText = items.isEmpty ? "インポートできる項目がありませんでした"
                                          : "\(items.count)件を定型文にインポートしました"
        alert.informativeText = items.isEmpty
            ? "テキスト形式(TEXT / UNICODE TEXT)のみ対応しています。"
            : url.lastPathComponent
        alert.runModal()
    }

    /// Open the folder where CLCL.ini is looked for, so a Windows ini can be dropped in.
    @objc private func openIniFolder() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        NSWorkspace.shared.open(base.appendingPathComponent("CLCL", isDirectory: true))
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
