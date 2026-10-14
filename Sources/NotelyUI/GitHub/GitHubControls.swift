import AppKit
import NotelyCore
import SwiftUI

/// Opens a list's GitHub menu and the repository picker, and links or
/// unlinks the list. A class, so it can be the target of the menu items
/// and the open popover outlives view updates.
@MainActor
final class GitHubControls: NSObject, ObservableObject, NSPopoverDelegate {
    var store: NoteStore?
    var account: GitHubAccount?
    var sync: SyncController?
    var id: UUID?
    /// Opens Settings on Integrations, for "Reconnect…".
    var onReconnect: () -> Void = {}
    /// The GitHub button: the picker opens at it and the link sheet on
    /// its window.
    private weak var button: NSButton?
    private var popover: NSPopover?

    /// Keeps the GitHub button, so "Link to Repository…" (Cmd+L) can open
    /// the picker at it before the button was ever clicked.
    func anchor(_ button: NSButton) {
        self.button = button
    }

    /// Cmd+L, from the GitHub menu in the menu bar: the picker for an
    /// unlinked list, and the GitHub button's menu ("Open on GitHub",
    /// "Unlink") for a linked one.
    /// Pressed again while the picker is open, it closes the picker.
    func showFromShortcut() {
        if let popover {
            popover.performClose(nil)
            return
        }
        guard let button, let store, let id else { return }
        if store.note(id)?.githubRepo != nil {
            showMenu(from: button)
        } else {
            showPicker(nil)
        }
    }

    func showMenu(from button: NSButton) {
        guard let store, let id, let note = store.note(id) else { return }
        self.button = button
        let menu = NSMenu()
        // Information rows are disabled; the repository row shows the
        // check mark but must not look disabled.
        menu.autoenablesItems = false
        if account?.tokenRejected == true {
            addInfo("GitHub token no longer works", to: menu)
            addItem("Reconnect…", #selector(reconnect(_:)), to: menu)
            menu.addItem(.separator())
        }
        if let repo = note.githubRepo {
            let current = NSMenuItem(title: repo, action: nil, keyEquivalent: "")
            current.state = .on
            menu.addItem(current)
            let pending = sync?.pendingCount(id) ?? 0
            if pending > 0 {
                addInfo(SyncController.pendingText(pending), to: menu)
            }
            if (sync?.heldCount(id) ?? 0) > 0 {
                addInfo(SyncController.heldReason, to: menu)
            }
            if let message = sync?.states[id]?.message {
                addInfo(message, to: menu)
            }
            menu.addItem(.separator())
            addItem("Open on GitHub", #selector(openOnGitHub(_:)), to: menu)
            addItem("Unlink", #selector(unlink(_:)), to: menu)
        } else {
            addItem("Link to Repository…", #selector(showPicker(_:)), to: menu)
        }
        // Cmd+L again closes the menu: a menu being shown takes the keys,
        // so the menu bar's item never sees it. Choosing any item closes
        // the menu, so this one does nothing else.
        let close = NSMenuItem(title: "Close", action: #selector(closeMenu(_:)), keyEquivalent: "l")
        close.target = self
        close.isHidden = true
        close.allowsKeyEquivalentWhenHidden = true
        menu.addItem(close)
        // Below the button, as the tint menu.
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }

    private func addItem(_ title: String, _ action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func addInfo(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    @objc private func closeMenu(_ sender: NSMenuItem) {}

    @objc private func reconnect(_ sender: NSMenuItem) {
        onReconnect()
    }

    @objc private func openOnGitHub(_ sender: NSMenuItem) {
        guard let id, let repo = store?.note(id)?.githubRepo,
              let url = URL(string: "https://github.com/\(repo)/issues") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func unlink(_ sender: NSMenuItem) {
        guard let id else { return }
        store?.unlink(id)
    }

    @objc private func showPicker(_ sender: NSMenuItem?) {
        guard let button, let sync else { return }
        let controller = NSHostingController(rootView: RepositoryPicker(
            service: sync.service,
            onCancel: { [weak self] in self?.popover?.performClose(nil) },
            onLink: { [weak self] repo in
                self?.popover?.performClose(nil)
                self?.link(repo)
            }
        ))
        controller.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        popover.delegate = self
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        self.popover = popover
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            popover = nil
        }
    }

    /// Links at once when the list has no unchecked items. Otherwise asks
    /// in a sheet whether to keep them, to be created as issues, or
    /// discard them. Esc cancels. A refresh follows every link.
    private func link(_ repo: String) {
        guard let store, let id, let note = store.note(id) else { return }
        let unchecked = (note.items ?? []).filter { !$0.done }.count
        guard unchecked > 0 else {
            store.link(id, repo: repo, keep: false)
            sync?.refresh(id)
            return
        }
        guard let window = button?.window, window.attachedSheet == nil else { return }
        let alert = NSAlert()
        alert.messageText = "Link “\(listTitle(note.title))” to \(repo)?"
        alert.informativeText = "This list has \(unchecked) unchecked \(unchecked == 1 ? "item" : "items"). "
            + "“Create as issues” creates them as issues in \(repo). “Discard” removes them. "
            + "Checked items are not kept."
        alert.addButton(withTitle: "Create as issues")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel").keyEquivalent = "\u{1b}"
        let sync = self.sync
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn:
                store.link(id, repo: repo, keep: true)
            case .alertSecondButtonReturn:
                store.link(id, repo: repo, keep: false)
            default:
                return
            }
            MainActor.assumeIsolated { sync?.refresh(id) }
        }
    }
}

/// The repository picker: the repositories the token reaches, filtered as
/// the user types, or any "owner/repo" typed in the field. "Link" checks
/// the repository with GitHub before linking.
struct RepositoryPicker: View {
    let service: any IssueService
    let onCancel: () -> Void
    let onLink: (String) -> Void
    @State private var query = ""
    /// `nil` while loading.
    @State private var repositories: [String]?
    @State private var loadFailed = false
    @State private var isChecking = false
    @State private var problem: String?

    private var repo: String? { repositoryName(query) }

    private var matches: [String] {
        let typed = query.trimmingCharacters(in: .whitespaces)
        guard let repositories else { return [] }
        guard !typed.isEmpty else { return repositories }
        return repositories.filter { $0.localizedCaseInsensitiveContains(typed) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search or type owner/repo", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit(check)
                .onChange(of: query) { problem = nil }
            results
                .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 180, alignment: .topLeading)
            if let problem {
                Text(problem)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                if isChecking {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Link", action: check)
                    .keyboardShortcut(.defaultAction)
                    .disabled(repo == nil || isChecking)
            }
        }
        .padding(12)
        .frame(width: 300)
        .task { await load() }
    }

    @ViewBuilder
    private var results: some View {
        if loadFailed {
            Text("Your repositories couldn't be loaded. Type a repository as owner/repo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if repositories == nil {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if matches.isEmpty {
            Text("No matching repositories. Type a repository as owner/repo.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(matches, id: \.self) { name in
                        Button {
                            query = name
                        } label: {
                            Text(name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 3)
                                .padding(.horizontal, 4)
                                .background(name == query ? Color.accentColor.opacity(0.2) : Color.clear)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @MainActor
    private func load() async {
        do {
            repositories = try await service.repositories()
        } catch {
            loadFailed = true
            repositories = []
        }
    }

    /// Links `repo` once GitHub confirms it exists, is reachable, and has
    /// issues turned on.
    private func check() {
        guard let repo, !isChecking else { return }
        isChecking = true
        problem = nil
        Task { @MainActor in
            defer { isChecking = false }
            do {
                let access = try await service.repository(repo)
                guard access.hasIssues else {
                    problem = "Issues are turned off for \(repo)."
                    return
                }
                onLink(repo)
            } catch IssueServiceError.notFound, IssueServiceError.forbidden(_), IssueServiceError.moved {
                problem = "Repository not found, or this token can't reach it."
            } catch let error as IssueServiceError {
                problem = error.reason + "."
            } catch {
                problem = IssueServiceError.offline.reason + "."
            }
        }
    }
}
