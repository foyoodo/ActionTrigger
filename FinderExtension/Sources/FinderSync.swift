import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {

    private var myFolderURL = URL(fileURLWithPath: "/")
    private let engine = FinderExtensionEngine()

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
        engine.menu(for: menuKind, target: self, action: #selector(onAction(_:)))
    }

    @objc private func onAction(_ sender: NSMenuItem) {
        engine.executeAction(from: sender)
    }
}
