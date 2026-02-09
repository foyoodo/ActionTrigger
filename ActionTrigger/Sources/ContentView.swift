import SwiftUI

struct ContentView: View {
    @StateObject private var store = ActionConfigStore.shared
    @State private var selection: UUID?

    var body: some View {
        NavigationSplitView {
            rulesList
        } detail: {
            detailView
        }
        .frame(minWidth: 940, minHeight: 620)
    }

    private var rulesList: some View {
        List(selection: $selection) {
            ForEach(store.config.rules) { rule in
                HStack(spacing: 12) {
                    Toggle(isOn: bindingForRuleEnabled(rule.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name)
                                .font(.headline)
                            Text(matcherSummary(rule.matcher))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
                .padding(.vertical, 4)
                .tag(rule.id)
                .contextMenu {
                    Button(role: .destructive) {
                        store.deleteRule(id: rule.id)
                        if selection == rule.id {
                            selection = nil
                        }
                    } label: {
                        Label("Delete Rule", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: store.moveRule)
        }
        .navigationTitle("Action Rules")
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: addRule) {
                    Label("Add Rule", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                Spacer()
            }
            .padding(12)
        }
    }

    private var detailView: some View {
        Group {
            if let selection, let binding = bindingForRule(selection) {
                RuleDetailView(rule: binding, onDelete: {
                    store.deleteRule(id: selection)
                    self.selection = nil
                })
            } else {
                VStack(spacing: 10) {
                    Text("Select a rule")
                        .font(.title2)
                    Text("Create rules to control which actions appear in Finder.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func addRule() {
        let newRule = ActionRule(
            name: "New Rule",
            matcher: ActionMatcher(kind: .fileExtension, value: "txt"),
            actions: [ActionItem(kind: .openWithApp, displayName: "TextEdit", path: "/System/Applications/TextEdit.app")]
        )
        store.addRule(newRule)
        selection = newRule.id
    }

    private func bindingForRule(_ id: UUID) -> Binding<ActionRule>? {
        guard store.config.rules.contains(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: { store.config.rules.first(where: { $0.id == id }) ?? fallbackRule(id: id) },
            set: { newValue in
                if let index = store.config.rules.firstIndex(where: { $0.id == id }) {
                    store.config.rules[index] = newValue
                    store.save()
                }
            }
        )
    }

    private func bindingForRuleEnabled(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: {
                store.config.rules.first(where: { $0.id == id })?.isEnabled ?? true
            },
            set: { newValue in
                if let index = store.config.rules.firstIndex(where: { $0.id == id }) {
                    store.config.rules[index].isEnabled = newValue
                    store.save()
                }
            }
        )
    }

    private func matcherSummary(_ matcher: ActionMatcher) -> String {
        switch matcher.kind {
        case .folder:
            return "Folder"
        case .fileExtension:
            return "Extension .\(matcher.value ?? "")"
        case .contentType:
            return "Type \((matcher.value ?? "").capitalized)"
        }
    }

    private func fallbackRule(id: UUID) -> ActionRule {
        ActionRule(
            id: id,
            name: "",
            matcher: ActionMatcher(kind: .fileExtension, value: ""),
            actions: []
        )
    }
}

#Preview {
    ContentView()
}
