import Cocoa
import FinderSync
import UniformTypeIdentifiers

final class FinderSync: FIFinderSync {

    private var myFolderURL = URL(fileURLWithPath: "/")
    private var menuContext: MenuContext?

    override init() {
        super.init()

        NSLog("FinderSync() launched from %@", Bundle.main.bundlePath as NSString)

        FIFinderSyncController.default().directoryURLs = [self.myFolderURL]
    }

    // MARK: - Primary Finder Sync protocol methods

    override func beginObservingDirectory(at url: URL) {
        NSLog("beginObservingDirectoryAtURL: %@", url.path as NSString)
    }

    override func endObservingDirectory(at url: URL) {
        NSLog("endObservingDirectoryAtURL: %@", url.path as NSString)
    }

    // MARK: - Menu and toolbar item support

    override var toolbarItemName: String {
        return "ActionTrigger"
    }

    override var toolbarItemToolTip: String {
        return "ActionTrigger: Click the toolbar item for a menu."
    }

    override var toolbarItemImage: NSImage {
        return NSImage(named: NSImage.cautionName)!
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else {
            return nil
        }

        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else {
            return nil
        }

        let primaryURL = urls[0]
        let resourceValues = try? primaryURL.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        let contentType = resourceValues?.contentType
        let isDirectory = resourceValues?.isDirectory ?? false

        let store = ActionConfigStore.shared
        store.reload()
        let matchingRules = store.config.rules.filter {
            ActionMatcherEvaluator.matches(rule: $0, url: primaryURL, contentType: contentType, isDirectory: isDirectory)
        }

        guard !matchingRules.isEmpty else {
            return nil
        }

        let context = MenuContext(urls: urls)
        let menu = buildMenu(matchingRules, context: context)
        menuContext = context
        return menu
    }

    @objc private func onAction(_ sender: NSMenuItem) {
        guard let context = menuContext,
              let action = context.action(for: sender.tag)
        else { return }

        switch action.kind {
        case .openWithApp:
            openWithApp(action: action, urls: context.urls)
        case .runScript:
            runScript(action: action, urls: context.urls)
        }
    }

    private func openWithApp(action: ActionItem, urls: [URL]) {
        guard let resolved = resolveActionURL(action) else { return }
        defer { if resolved.securityScoped { resolved.url.stopAccessingSecurityScopedResource() } }
        let appPath = resolved.url.path
        for url in urls {
            openWithHelper(url: url, appPath: appPath)
        }
    }

    private func runScript(action: ActionItem, urls: [URL]) {
        guard let resolved = resolveActionURL(action) else { return }
        defer { if resolved.securityScoped { resolved.url.stopAccessingSecurityScopedResource() } }
        let scriptPath = resolved.url.path
        for url in urls {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/zsh")
            task.arguments = [scriptPath, url.path]
            do {
                try task.run()
            } catch {
                NSLog("Failed to run script %@: %@", scriptPath, error.localizedDescription)
            }
        }
    }

    private func resolveActionURL(_ action: ActionItem) -> ResolvedURL? {
        if let data = action.bookmarkData {
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], bookmarkDataIsStale: &isStale)
                let started = url.startAccessingSecurityScopedResource()
                return ResolvedURL(url: url, securityScoped: started)
            } catch {
                NSLog("Failed to resolve bookmark for %@: %@", action.displayName, error.localizedDescription)
            }
        }

        guard !action.path.isEmpty else { return nil }
        return ResolvedURL(url: URL(fileURLWithPath: action.path), securityScoped: false)
    }

    private func openWithHelper(url: URL, appPath: String) {
        let connection = NSXPCConnection(serviceName: "com.foyoodo.ActionTrigger.xpc")
        connection.remoteObjectInterface = NSXPCInterface(with: ActionTriggerHelperXPCProtocol.self)
        connection.resume()

        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            NSLog("XPC open failed: %@", error.localizedDescription)
        } as? ActionTriggerHelperXPCProtocol

        proxy?.openFile(url: url, withApp: appPath) { _, _ in
            connection.invalidate()
        }
    }

    private func buildMenu(_ rules: [ActionRule], context: MenuContext) -> NSMenu {
        let menu = NSMenu(title: "ActionTrigger")

        for (index, rule) in rules.enumerated() {
            let actions = rule.actions.filter { $0.isEnabled }
            guard !actions.isEmpty else { continue }
            for action in actions {
                let tag = context.register(action: action)
                let item = NSMenuItem(title: action.displayName, action: #selector(onAction(_:)), keyEquivalent: "")
                item.target = self
                item.tag = tag
                if let icon = iconForAction(action) {
                    icon.size = NSSize(width: 16, height: 16)
                    item.image = icon
                }
                menu.addItem(item)
            }

            if index < rules.count - 1 {
                menu.addItem(.separator())
            }
        }

        return menu
    }

    private func iconForAction(_ action: ActionItem) -> NSImage? {
        switch action.kind {
        case .openWithApp:
            guard !action.path.isEmpty else { return nil }
            return NSWorkspace.shared.icon(forFile: action.path)
        case .runScript:
            if !action.path.isEmpty {
                return NSWorkspace.shared.icon(forFile: action.path)
            }
            return NSImage(named: NSImage.actionTemplateName)
        }
    }
}

private struct ResolvedURL {
    let url: URL
    let securityScoped: Bool
}

private final class MenuContext {
    let urls: [URL]
    private var nextTag: Int = 1
    private var actionsByTag: [Int: ActionItem] = [:]

    init(urls: [URL]) {
        self.urls = urls
    }

    func register(action: ActionItem) -> Int {
        let tag = nextTag
        nextTag += 1
        actionsByTag[tag] = action
        return tag
    }

    func action(for tag: Int) -> ActionItem? {
        actionsByTag[tag]
    }
}
