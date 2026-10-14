import AppKit
import NotelyCore
import NotelyLinks
import SwiftUI

/// Fill of a checked item's circle: white in dark appearance, dark gray
/// in light appearance, where white would not show.
let checkFill = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .white : .darkGray
})

/// The circle at the start of an item: an outline when unchecked, filled
/// when checked. A plain button never takes keyboard focus, so clicking
/// it leaves the item being edited alone.
struct CheckCircle: View {
    let done: Bool
    /// `false` for an issue the user may not close or reopen: the circle
    /// shows dimmed and ignores clicks.
    var isEnabled = true
    let action: () -> Void

    private var tooltip: String {
        isEnabled ? "" : "You can't close this issue"
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                if done {
                    Circle().fill(checkFill)
                } else {
                    Circle().strokeBorder(Color.secondary, lineWidth: 1.5)
                }
            }
            .frame(width: 18, height: 18)
            .frame(width: 24, height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .help(tooltip)
        .accessibilityLabel(done ? "Uncheck Item" : "Check Item")
    }
}

/// One row below a list's title, in display order.
enum ListRow: Identifiable {
    case item(ListItem)
    case newItem

    var id: String {
        switch self {
        case .item(let item): return item.id.uuidString
        case .newItem: return "new-item"
        }
    }

    var target: FocusTarget {
        switch self {
        case .item(let item): return .item(item.id)
        case .newItem: return .newItem
        }
    }
}

/// A list window's content: the shared strip, the title, the items, and
/// the "New item" row between unchecked and checked items.
struct ListView: View {
    let store: NoteStore
    let appearance: TextAppearance
    let account: GitHubAccount
    let sync: SyncController
    let linkPages: LinkPageStore
    let id: UUID
    var onClose: () -> Void
    var onDelete: () -> Void
    var onSettings: (SettingsPane) -> Void
    @StateObject private var focus = ListFocus()

    private var items: [ListItem] { store.note(id)?.items ?? [] }

    /// A list linked to a repository follows the issue-sync rules.
    private var isLinked: Bool { store.note(id)?.githubRepo != nil }

    /// One array for one `ForEach`, so an item keeps its identity when it
    /// moves between the unchecked and checked groups and slides there.
    private var rows: [ListRow] {
        let unchecked: [ListRow] = items.filter { !$0.done }.map(ListRow.item)
        let checked: [ListRow] = items.filter(\.done).map(ListRow.item)
        return unchecked + [.newItem] + checked
    }

    private var order: [FocusTarget] {
        [.title] + rows.map(\.target)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    LinkCardAbove(text: store.note(id)?.title ?? "", pages: linkPages) {
                        ListField(text: store.note(id)?.title ?? "",
                                  placeholder: "Untitled list",
                                  font: appearance.nsFont(bold: true),
                                  isTitle: true,
                                  target: .title,
                                  focus: focus,
                                  onChange: { store.setTitle($0, for: id) },
                                  onCommand: { handle($0, at: .title) })
                    }
                    .padding(.bottom, 2)

                    ForEach(rows) { row in
                        rowView(row)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                // Reaches down to the bottom of the visible area, so a
                // click on the empty space below the rows ends editing.
                .frame(minHeight: proxy.size.height, alignment: .top)
                .background(EndEditingView(drags: false))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, barHeight + barGap)
        .padding(.bottom, bottomBarHeight + barGap)
        // The bars are overlays, not rows of a stack: AppKit orders the
        // scroll view's NSScrollView above views declared before it, and
        // it reaches up under the transparent title bar, where it took
        // the clicks meant for "−" and trash.
        .overlay(alignment: .top) {
            NoteStrip(onClose: onClose, onDelete: onDelete)
        }
        .overlay(alignment: .bottom) {
            BottomBar(store: store, account: account, sync: sync, id: id, onSettings: onSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoteBackground(tint: store.note(id)?.tint))
        // Fill the transparent title bar too, as in note windows.
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func rowView(_ row: ListRow) -> some View {
        switch row {
        case .item(let item):
            let editable = sync.isEditable(item, in: id)
            // The card lines up with the item's text, past the circle.
            LinkCardAbove(text: item.text, pages: linkPages, indent: 24 + 6) {
                HStack(alignment: .top, spacing: 6) {
                    CheckCircle(done: item.done, isEnabled: editable) { toggle(item.id) }
                    ListField(text: item.text,
                              placeholder: "",
                              font: appearance.nsFont(bold: false),
                              done: item.done,
                              canToggle: true,
                              isEditable: editable,
                              target: .item(item.id),
                              focus: focus,
                              onChange: { store.setItemText($0, item: item.id, for: id) },
                              onBeginEditing: { sync.setFocused(item.id, in: id) },
                              onEndEditing: { endEditing(item.id) },
                              onCommand: { handle($0, at: .item(item.id)) })
                        .padding(.top, 3)
                }
            }
        case .newItem:
            HStack(alignment: .top, spacing: 6) {
                // No circle: "New item" cannot be checked.
                Color.clear.frame(width: 24, height: 24)
                ListField(text: "",
                          placeholder: "New item",
                          font: appearance.nsFont(bold: false),
                          target: .newItem,
                          focus: focus,
                          onChange: { text in
                              guard !text.isEmpty else { return }
                              focus.request = .item(store.appendItem(text, for: id))
                          },
                          onCommand: { handle($0, at: .newItem) })
                    .padding(.top, 3)
            }
        }
    }

    /// Checks or unchecks an item. On a linked list, only an item the user
    /// may close or reopen, and the change is sent to GitHub.
    private func toggle(_ itemID: UUID) {
        guard let item = items.first(where: { $0.id == itemID }), sync.isEditable(item, in: id) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            store.toggleItem(itemID, for: id)
        }
        if isLinked {
            sync.itemsChanged(id)
        }
    }

    /// An item lost keyboard focus. On a linked list, an emptied item with
    /// an issue gets its issue's title back instead of being removed, and
    /// the list's changes are sent.
    private func endEditing(_ itemID: UUID) {
        if sync.focused[id] == itemID {
            sync.setFocused(nil, in: id)
        }
        guard isLinked else {
            removeIfEmpty(itemID)
            return
        }
        if let item = items.first(where: { $0.id == itemID }), item.text.isEmpty, item.issueNumber != nil {
            store.setItemText(item.remoteTitle ?? "", item: itemID, for: id)
        } else {
            removeIfEmpty(itemID)
        }
        sync.itemsChanged(id)
    }

    /// An item left empty when it loses keyboard focus is removed.
    private func removeIfEmpty(_ itemID: UUID) {
        guard items.first(where: { $0.id == itemID })?.text.isEmpty == true else { return }
        store.removeItem(itemID, for: id)
    }

    /// Handles a key a field passed up; returns false to let the field
    /// edit as usual.
    private func handle(_ command: ListCommand, at target: FocusTarget) -> Bool {
        let targets = order
        guard let index = targets.firstIndex(of: target) else { return false }
        switch command {
        case .returnKey:
            switch target {
            case .title:
                let firstItem = items.first.map { FocusTarget.item($0.id) }
                focus.request = firstItem ?? .newItem
            case .item(let itemID):
                if items.first(where: { $0.id == itemID })?.done == true {
                    focus.request = .newItem
                } else {
                    focus.request = .item(store.insertItem(after: itemID, for: id))
                }
            case .newItem:
                break
            }
            return true
        case .deleteEmpty:
            guard case .item(let itemID) = target, index > 0 else { return false }
            // An item with an issue cannot be emptied away: GitHub keeps
            // the issue, so the item stays.
            if isLinked, items.first(where: { $0.id == itemID })?.issueNumber != nil {
                return true
            }
            store.removeItem(itemID, for: id)
            focus.request = targets[index - 1]
            return true
        case .up:
            guard index > 0 else { return false }
            focus.request = targets[index - 1]
            return true
        case .down:
            guard index + 1 < targets.count else { return false }
            focus.request = targets[index + 1]
            return true
        case .toggle:
            guard case .item(let itemID) = target else { return false }
            toggle(itemID)
            return true
        }
    }
}
