import SwiftUI
import UniformTypeIdentifiers

struct RuleDetailView: View {
    @Binding var rule: ActionRule
    var onDelete: () -> Void

    @State private var editingActionID: UUID?
    @State private var appSelection: Set<UUID> = []
    @State private var scriptSelection: Set<UUID> = []
    @State private var isDropTarget = false
    @State private var draggingAppID: UUID?
    @State private var draggingScriptID: UUID?

    var body: some View {
        VStack(spacing: 16) {
            headerSection
            HStack(alignment: .top, spacing: 16) {
                appsSection
                scriptsSection
            }
        }
        .padding(20)
        .navigationTitle(rule.name)
        .onChange(of: rule) {
            ActionConfigStore.shared.save()
        }
    }

    private var headerSection: some View {
        GroupBox {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rule Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Name", text: $rule.name)
                        .textFieldStyle(.roundedBorder)
                }
                Divider()
                MatcherEditor(matcher: $rule.matcher)
                    .frame(maxWidth: 280)
                Spacer()
            }
            .padding(4)
        } label: {
            Text("Rule")
                .font(.headline)
        }
    }

    private var appsSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                Table(appActions, selection: $appSelection) {
                    TableColumn("") { action in
                        Toggle("", isOn: bindingForActionEnabled(action.id))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    .width(34)

                    TableColumn("App") { action in
                        HStack(spacing: 8) {
                            AppIconView(path: action.path)
                            editableTitle(for: action)
                        }
                        .onDrag {
                            draggingAppID = action.id
                            return NSItemProvider(object: action.id.uuidString as NSString)
                        }
                        .onDrop(of: [UTType.text.identifier], delegate: ActionDropDelegate(
                            item: action,
                            kind: .openWithApp,
                            actions: $rule.actions,
                            draggingID: $draggingAppID,
                            onMove: moveAction
                        ))
                    }

                    TableColumn("Path") { action in
                        Text(action.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(minHeight: 260)
                .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget, perform: handleAppDrop)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isDropTarget ? Color.accentColor : Color.clear, lineWidth: 2)
                )

                HStack {
                    Button("Add App", action: addAppFromPanel)
                    Button("Remove", action: deleteSelectedApps)
                        .disabled(appSelection.isEmpty)
                    Spacer()
                    Text("Drag .app bundles into the list")
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Text("Apps")
                .font(.headline)
        }
    }

    private var scriptsSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                Table(scriptActions, selection: $scriptSelection) {
                    TableColumn("") { action in
                        Toggle("", isOn: bindingForActionEnabled(action.id))
                            .toggleStyle(.checkbox)
                            .labelsHidden()
                    }
                    .width(34)

                    TableColumn("Script") { action in
                        HStack(spacing: 8) {
                            ScriptIconView(path: action.path)
                            editableTitle(for: action)
                        }
                        .onDrag {
                            draggingScriptID = action.id
                            return NSItemProvider(object: action.id.uuidString as NSString)
                        }
                        .onDrop(of: [UTType.text.identifier], delegate: ActionDropDelegate(
                            item: action,
                            kind: .runScript,
                            actions: $rule.actions,
                            draggingID: $draggingScriptID,
                            onMove: moveAction
                        ))
                    }

                    TableColumn("Path") { action in
                        Text(action.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(minHeight: 260)

                HStack {
                    Button("Add Script", action: addScriptFromPanel)
                    Button("Remove", action: deleteSelectedScripts)
                        .disabled(scriptSelection.isEmpty)
                    Spacer()
                }
            }
        } label: {
            Text("Scripts")
                .font(.headline)
        }
    }

    private var appActions: [ActionItem] {
        rule.actions.filter { $0.kind == .openWithApp }
    }

    private var scriptActions: [ActionItem] {
        rule.actions.filter { $0.kind == .runScript }
    }

    private func editableTitle(for action: ActionItem) -> some View {
        let isEditing = editingActionID == action.id
        return Group {
            if isEditing {
                TextField("Display Name", text: bindingForActionName(action.id), onCommit: { editingActionID = nil })
                    .textFieldStyle(.roundedBorder)
            } else {
                Text(action.displayName.isEmpty ? "Untitled" : action.displayName)
                    .onTapGesture(count: 2) { editingActionID = action.id }
            }
        }
    }

    private func bindingForAction(_ id: UUID) -> Binding<ActionItem>? {
        guard let index = rule.actions.firstIndex(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { rule.actions[index] },
            set: { newValue in
                rule.actions[index] = newValue
                ActionConfigStore.shared.save()
            }
        )
    }

    private func bindingForActionEnabled(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: {
                rule.actions.first(where: { $0.id == id })?.isEnabled ?? true
            },
            set: { newValue in
                if let index = rule.actions.firstIndex(where: { $0.id == id }) {
                    rule.actions[index].isEnabled = newValue
                    ActionConfigStore.shared.save()
                }
            }
        )
    }

    private func bindingForActionName(_ id: UUID) -> Binding<String> {
        Binding(
            get: {
                rule.actions.first(where: { $0.id == id })?.displayName ?? ""
            },
            set: { newValue in
                if let index = rule.actions.firstIndex(where: { $0.id == id }) {
                    rule.actions[index].displayName = newValue
                    ActionConfigStore.shared.save()
                }
            }
        )
    }

    private func deleteSelectedApps() {
        rule.actions.removeAll { appSelection.contains($0.id) }
        appSelection.removeAll()
        ActionConfigStore.shared.save()
    }

    private func deleteSelectedScripts() {
        rule.actions.removeAll { scriptSelection.contains($0.id) }
        scriptSelection.removeAll()
        ActionConfigStore.shared.save()
    }

    private func moveAction(kind: ActionKind, from: UUID, to: UUID) {
        guard from != to else { return }
        var kindActions = rule.actions.filter { $0.kind == kind }
        guard let fromIndex = kindActions.firstIndex(where: { $0.id == from }),
              let toIndex = kindActions.firstIndex(where: { $0.id == to }) else {
            return
        }
        let item = kindActions.remove(at: fromIndex)
        kindActions.insert(item, at: toIndex)

        var iterator = kindActions.makeIterator()
        for index in rule.actions.indices {
            if rule.actions[index].kind == kind, let next = iterator.next() {
                rule.actions[index] = next
            }
        }
        ActionConfigStore.shared.save()
    }

    private func handleAppDrop(providers: [NSItemProvider]) -> Bool {
        let typeId = UTType.fileURL.identifier
        var didHandle = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(typeId) {
            didHandle = true
            provider.loadItem(forTypeIdentifier: typeId, options: nil) { item, _ in
                if let url = fileURL(from: item), url.pathExtension.lowercased() == "app" {
                    DispatchQueue.main.async {
                        addApp(url: url)
                    }
                }
            }
        }
        return didHandle
    }

    private func addAppFromPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.application]
        if panel.runModal() == .OK {
            for url in panel.urls {
                addApp(url: url)
            }
        }
    }

    private func addApp(url: URL) {
        guard url.pathExtension.lowercased() == "app" else { return }
        if rule.actions.contains(where: { $0.kind == .openWithApp && $0.path == url.path }) { return }
        let displayName = appDisplayName(for: url)
        let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
        rule.actions.append(ActionItem(kind: .openWithApp, displayName: displayName, path: url.path, isEnabled: true, bookmarkData: bookmark))
        ActionConfigStore.shared.save()
    }

    private func addScriptFromPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [UTType.item]
        if panel.runModal() == .OK, let url = panel.url {
            let displayName = url.deletingPathExtension().lastPathComponent
            let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            rule.actions.append(ActionItem(kind: .runScript, displayName: displayName, path: url.path, isEnabled: true, bookmarkData: bookmark))
            ActionConfigStore.shared.save()
        }
    }

    private func appDisplayName(for url: URL) -> String {
        if let bundle = Bundle(url: url) {
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                return name
            }
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                return name
            }
        }
        return url.deletingPathExtension().lastPathComponent
    }

    private func fileURL(from item: Any?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        return nil
    }
}

struct MatcherEditor: View {
    @Binding var matcher: ActionMatcher

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Match")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("Match", selection: $matcher.kind) {
                ForEach(ActionMatcherKind.allCases) { kind in
                    Text(label(for: kind)).tag(kind)
                }
            }
            .pickerStyle(.menu)

            switch matcher.kind {
            case .folder:
                Text("Folders only")
                    .foregroundStyle(.secondary)
            case .fileExtension:
                TextField("Extension (without dot)", text: Binding(
                    get: { matcher.value ?? "" },
                    set: { matcher.value = $0.lowercased() }
                ))
                .textFieldStyle(.roundedBorder)
            case .contentType:
                Picker("File Type", selection: Binding(
                    get: { matcher.value ?? FileCategory.image.rawValue },
                    set: { matcher.value = $0 }
                )) {
                    ForEach(FileCategory.allCases) { category in
                        Text(category.rawValue.capitalized).tag(category.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func label(for kind: ActionMatcherKind) -> String {
        switch kind {
        case .folder: return "Folder"
        case .fileExtension: return "File Extension"
        case .contentType: return "Content Type"
        }
    }
}

struct AppIconView: View {
    let path: String

    var body: some View {
        iconImage
            .resizable()
            .frame(width: 18, height: 18)
            .cornerRadius(4)
    }

    private var iconImage: Image {
        if !path.isEmpty {
            let icon = NSWorkspace.shared.icon(forFile: path)
            return Image(nsImage: icon)
        }
        return Image(nsImage: NSImage(named: NSImage.applicationIconName) ?? NSImage())
    }
}

struct ScriptIconView: View {
    let path: String

    var body: some View {
        iconImage
            .resizable()
            .frame(width: 18, height: 18)
            .cornerRadius(4)
    }

    private var iconImage: Image {
        if !path.isEmpty {
            let icon = NSWorkspace.shared.icon(forFile: path)
            return Image(nsImage: icon)
        }
        return Image(nsImage: NSImage(named: NSImage.actionTemplateName) ?? NSImage())
    }
}

private struct ActionDropDelegate: DropDelegate {
    let item: ActionItem
    let kind: ActionKind
    @Binding var actions: [ActionItem]
    @Binding var draggingID: UUID?
    let onMove: (ActionKind, UUID, UUID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != item.id else { return }
        onMove(kind, draggingID, item.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingID != nil
    }
}
