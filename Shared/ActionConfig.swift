import Foundation
import Combine
import UniformTypeIdentifiers

public enum ActionMatcherKind: String, Codable, CaseIterable, Identifiable {
    case folder
    case fileExtension
    case contentType

    public var id: String { rawValue }
}

public enum FileCategory: String, Codable, CaseIterable, Identifiable {
    case image
    case text
    case video
    case audio
    case archive
    case pdf

    public var id: String { rawValue }
}

public struct ActionMatcher: Codable, Equatable {
    public var kind: ActionMatcherKind
    public var value: String?

    public init(kind: ActionMatcherKind, value: String? = nil) {
        self.kind = kind
        self.value = value
    }
}

public enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case openWithApp
    case runScript

    public var id: String { rawValue }
}

public struct ActionItem: Codable, Identifiable, Equatable {
    public var id: UUID
    public var kind: ActionKind
    public var displayName: String
    public var path: String
    public var isEnabled: Bool
    public var bookmarkData: Data?

    public init(id: UUID = UUID(), kind: ActionKind, displayName: String, path: String, isEnabled: Bool = true, bookmarkData: Data? = nil) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.path = path
        self.isEnabled = isEnabled
        self.bookmarkData = bookmarkData
    }
}

public struct ActionRule: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var matcher: ActionMatcher
    public var actions: [ActionItem]
    public var isEnabled: Bool

    public init(id: UUID = UUID(), name: String, matcher: ActionMatcher, actions: [ActionItem], isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.matcher = matcher
        self.actions = actions
        self.isEnabled = isEnabled
    }
}

public struct ActionConfig: Codable, Equatable {
    public var version: Int
    public var rules: [ActionRule]

    public init(version: Int = 1, rules: [ActionRule]) {
        self.version = version
        self.rules = rules
    }
}

public enum ActionConfigDefaults {
    public static let appGroupID = "com.foyoodo.ActionTrigger.Groups"
    public static let fileName = "action-config.json"

    public static func defaultConfig() -> ActionConfig {
        ActionConfig(rules: [
            ActionRule(
                name: "Images",
                matcher: ActionMatcher(kind: .contentType, value: FileCategory.image.rawValue),
                actions: [
                    ActionItem(kind: .openWithApp, displayName: "Preview", path: "/System/Applications/Preview.app")
                ]
            ),
            ActionRule(
                name: "Text",
                matcher: ActionMatcher(kind: .contentType, value: FileCategory.text.rawValue),
                actions: [
                    ActionItem(kind: .openWithApp, displayName: "TextEdit", path: "/System/Applications/TextEdit.app")
                ]
            ),
            ActionRule(
                name: "Videos",
                matcher: ActionMatcher(kind: .contentType, value: FileCategory.video.rawValue),
                actions: [
                    ActionItem(kind: .openWithApp, displayName: "QuickTime Player", path: "/System/Applications/QuickTime Player.app")
                ]
            ),
            ActionRule(
                name: "Folders",
                matcher: ActionMatcher(kind: .folder),
                actions: [
                    ActionItem(kind: .openWithApp, displayName: "Terminal", path: "/System/Applications/Utilities/Terminal.app")
                ]
            )
        ])
    }
}

public final class ActionConfigStore: ObservableObject {
    public static let shared = ActionConfigStore()

    @Published public var config: ActionConfig = ActionConfigDefaults.defaultConfig()

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        loadOrSeed()
    }

    public func loadOrSeed() {
        if let data = try? Data(contentsOf: configURL()),
           let decoded = try? decoder.decode(ActionConfig.self, from: data) {
            config = decoded
            return
        }

        config = ActionConfigDefaults.defaultConfig()
        save()
    }

    public func reload() {
        if let data = try? Data(contentsOf: configURL()),
           let decoded = try? decoder.decode(ActionConfig.self, from: data) {
            config = decoded
        }
    }

    public func save() {
        do {
            let data = try encoder.encode(config)
            try data.write(to: configURL(), options: [.atomic])
        } catch {
            NSLog("ActionConfigStore save failed: %@", error.localizedDescription)
        }
    }

    public func resetToDefaults() {
        config = ActionConfigDefaults.defaultConfig()
        save()
    }

    public func addRule(_ rule: ActionRule) {
        config.rules.append(rule)
        save()
    }

    public func deleteRule(id: UUID) {
        config.rules.removeAll { $0.id == id }
        save()
    }

    public func moveRule(from offsets: IndexSet, to index: Int) {
        config.rules.moveIndexes(fromOffsets: offsets, toOffset: index)
        save()
    }

    public func configURL() -> URL {
        if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ActionConfigDefaults.appGroupID) {
            return containerURL.appending(path: ActionConfigDefaults.fileName)
        }
        return FileManager.default.temporaryDirectory.appending(path: ActionConfigDefaults.fileName)
    }
}

private extension Array {
    mutating func moveIndexes(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let elements = offsets.map { self[$0] }
        var adjustedDestination = destination
        for offset in offsets.reversed() {
            remove(at: offset)
            if offset < adjustedDestination {
                adjustedDestination -= 1
            }
        }
        insert(contentsOf: elements, at: adjustedDestination)
    }
}

public enum ActionMatcherEvaluator {
    public static func matches(rule: ActionRule, url: URL, contentType: UTType?, isDirectory: Bool) -> Bool {
        guard rule.isEnabled else { return false }
        switch rule.matcher.kind {
        case .folder:
            return isDirectory
        case .fileExtension:
            let ext = (rule.matcher.value ?? "").lowercased()
            guard !ext.isEmpty else { return false }
            return url.pathExtension.lowercased() == ext
        case .contentType:
            guard let value = rule.matcher.value, let category = FileCategory(rawValue: value) else {
                return false
            }
            return conforms(contentType: contentType, to: category)
        }
    }

    private static func conforms(contentType: UTType?, to category: FileCategory) -> Bool {
        guard let type = contentType else { return false }
        switch category {
        case .image:
            return type.conforms(to: .image)
        case .text:
            return type.conforms(to: .text)
        case .video:
            return type.conforms(to: .movie) || type.conforms(to: .video)
        case .audio:
            return type.conforms(to: .audio)
        case .archive:
            return type.conforms(to: .zip) || type.conforms(to: .archive)
        case .pdf:
            return type.conforms(to: .pdf)
        }
    }
}
