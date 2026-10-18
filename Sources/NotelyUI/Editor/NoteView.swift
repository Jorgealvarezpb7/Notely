import AppKit
import NotelyCore
import NotelyLinks
import SwiftUI

/// A note window's content: the list editor for lists, the text editor
/// for everything else.
struct WindowContent: View {
    let store: NoteStore
    let appearance: TextAppearance
    let account: GitHubAccount
    let sync: SyncController
    let linkPages: LinkPageStore
    let id: UUID
    var onClose: () -> Void
    var onDelete: () -> Void
    var onSettings: (SettingsPane) -> Void

    var body: some View {
        if store.note(id)?.isList == true {
            ListView(store: store, appearance: appearance, account: account, sync: sync, linkPages: linkPages, id: id,
                     onClose: onClose, onDelete: onDelete, onSettings: onSettings)
        } else {
            NoteView(store: store, appearance: appearance, account: account, sync: sync, linkPages: linkPages, id: id,
                     onClose: onClose, onDelete: onDelete, onSettings: onSettings)
        }
    }
}

struct NoteView: View {
    let store: NoteStore
    let appearance: TextAppearance
    let account: GitHubAccount
    let sync: SyncController
    let linkPages: LinkPageStore
    let id: UUID
    var onClose: () -> Void
    var onDelete: () -> Void
    var onSettings: (SettingsPane) -> Void
    @StateObject private var editorState = NoteEditorState()

    var body: some View {
        NoteEditor(store: store, appearance: appearance, linkPages: linkPages, family: appearance.family,
                   size: appearance.size, id: id, state: editorState)
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
        // 6 here and 6 of text inset in `NoteEditor`: the text sits 12
        // from the edges, and the scroller 6, clear of the cards.
        .padding(.horizontal, 6)
        .padding(.top, barHeight + barGap)
        .padding(.bottom, bottomBarHeight + barGap)
        // The bars are overlays outside the padding, so their fill runs
        // from edge to edge, as in list windows.
        .overlay(alignment: .top) {
            NoteStrip(onClose: onClose, onDelete: onDelete)
        }
        .overlay(alignment: .bottom) {
            BottomBar(store: store, account: account, sync: sync, id: id, editorState: editorState, onSettings: onSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoteBackground(tint: store.note(id)?.tint))
        // Fill the transparent title bar too, so the top bar sits at the
        // top edge of the window.
        .ignoresSafeArea()
    }
}

/// A note window's editor as the bottom bar sees it: the styles that
/// apply at the caret or to the whole selection (none while the note
/// does not have keyboard focus), and the text view to toggle them in.
final class NoteEditorState: ObservableObject {
    @Published var active: Set<TextStyle> = []
    weak var textView: NoteTextView?
}

/// The Bold, Italic, and Underline buttons of a note's bottom bar.
struct StyleButtons: View {
    @ObservedObject var state: NoteEditorState

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TextStyle.allCases, id: \.self) { style in
                StripButton(symbolName: style.symbolName, accessibilityLabel: style.title,
                            isOn: state.active.contains(style)) { _ in
                    state.textView?.toggle(style)
                }
                .frame(width: StripButton.referenceSize.width,
                       height: StripButton.referenceSize.height)
            }
        }
    }
}
