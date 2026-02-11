import Cocoa
import FinderSync
import UniformTypeIdentifiers

final class FinderExtensionEngine {

    func menu(for menuKind: FIMenuKind, target: AnyObject, action: Selector) -> NSMenu? {
        guard menuKind == .contextualMenuForItems else {
            return nil
        }

        guard let urls = FIFinderSyncController.default().selectedItemURLs(), !urls.isEmpty else {
            return nil
        }

        let matchingRules = matchingRules(for: urls)
        guard !matchingRules.isEmpty else {
            return nil
        }

        return buildMenu(matchingRules, urls: urls, target: target, action: action)
    }

    func executeAction(from sender: NSMenuItem) {
        guard let payload = sender.representedObject as? MenuItemPayload else { return }

        switch payload.action.kind {
        case .openWithApp:
            openWithApp(payload.action, urls: payload.urls)
        case .runScript:
            runScript(payload.action, urls: payload.urls)
        }
    }

    private func matchingRules(for urls: [URL]) -> [ActionRule] {
        guard let primaryURL = urls.first else { return [] }
        let resourceValues = try? primaryURL.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey])
        let contentType = resourceValues?.contentType
        let isDirectory = resourceValues?.isDirectory ?? false

        let store = ActionConfigStore.shared
        store.reload()
        return store.config.rules.filter {
            ActionMatcherEvaluator.matches(rule: $0, url: primaryURL, contentType: contentType, isDirectory: isDirectory)
        }
    }

    private func buildMenu(_ rules: [ActionRule], urls: [URL], target: AnyObject, action: Selector) -> NSMenu {
        let menu = NSMenu(title: "ActionTrigger")
        let actionGroups = rules.map { $0.actions.filter(\.isEnabled) }.filter { !$0.isEmpty }

        for groupIndex in actionGroups.indices {
            for actionItem in actionGroups[groupIndex] {
                let item = NSMenuItem(title: actionItem.displayName, action: action, keyEquivalent: "")
                item.target = target
                item.representedObject = MenuItemPayload(action: actionItem, urls: urls)

                if let icon = iconForAction(actionItem) {
                    icon.size = NSSize(width: 16, height: 16)
                    item.image = icon
                }
                menu.addItem(item)
            }

            if groupIndex < actionGroups.count - 1 {
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

    private func openWithApp(_ action: ActionItem, urls: [URL]) {
        guard let resolved = resolveActionURL(action) else { return }
        defer { if resolved.securityScoped { resolved.url.stopAccessingSecurityScopedResource() } }
        let appPath = resolved.url.path

        for url in urls {
            openWithHelper(url: url, appPath: appPath)
        }
    }

    private func runScript(_ action: ActionItem, urls: [URL]) {
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
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: [.withSecurityScope],
                    bookmarkDataIsStale: &isStale
                )
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
}

private struct ResolvedURL {
    let url: URL
    let securityScoped: Bool
}

private final class MenuItemPayload: NSObject {
    let action: ActionItem
    let urls: [URL]

    init(action: ActionItem, urls: [URL]) {
        self.action = action
        self.urls = urls
    }
}
