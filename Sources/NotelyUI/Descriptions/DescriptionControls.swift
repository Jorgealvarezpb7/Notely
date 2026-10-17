import AppKit
import NotelyCore
import SwiftUI

/// Opens a linked list item's description popover at the item's
/// description icon, one item at a time, and ends description editing
/// when the popover closes. A class, so the open popover outlives view
/// updates; one per list window.
@MainActor
final class DescriptionControls: NSObject, ObservableObject, NSPopoverDelegate {
    var store: NoteStore?
    var sync: SyncController?
    var id: UUID?
    /// The item whose popover is open, so its icon stays shown.
    @Published private(set) var openItem: UUID?
    /// The linked row under the pointer: its icon shows, and Cmd+D opens
    /// its popover when no item is being edited.
    @Published var hoveredItem: UUID?

    private final class WeakButton {
        weak var button: NSButton?
        init(_ button: NSButton) { self.button = button }
    }

    /// Each linked row's description icon, to open the popover at it.
    private var anchors: [UUID: WeakButton] = [:]
    private var popover: NSPopover?
    /// The item whose description is being edited in the open popover.
    @Published private(set) var editingItem: UUID?
    /// The description being edited. Typing changes only this; it is
    /// stored when editing ends, so each key is not saved or re-rendered.
    @Published var draft = ""

    func register(_ button: NSButton, for item: UUID) {
        anchors[item] = WeakButton(button)
    }

    /// The icon's click: opens the item's popover, or closes it when open.
    func toggle(_ item: UUID) {
        if openItem == item {
            popover?.performClose(nil)
        } else {
            show(item)
        }
    }

    /// Cmd+D: closes the open popover, or opens the item's.
    func toggleFromShortcut(_ item: UUID?) {
        if openItem != nil {
            popover?.performClose(nil)
        } else if let item {
            show(item)
        }
    }

    /// Opens the item's popover, closing another item's first.
    func show(_ item: UUID) {
        guard let store, let sync, let id, let button = anchors[item]?.button, button.window != nil else { return }
        if let popover {
            // Ends the other item's editing at once, so it is sent.
            popover.close()
            closed()
        }
        let controller = TintedPopoverController(rootView: DescriptionPopover(
            store: store,
            sync: sync,
            id: id,
            itemID: item,
            controls: self
        ))
        controller.tint = tintColor(store.note(id)?.tint)
        controller.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        popover.delegate = self
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxX)
        self.popover = popover
        openItem = item
    }

    /// "Edit": the draft starts from the item's description.
    func beginEditing(_ item: UUID) {
        guard let store, let sync, let id else { return }
        draft = store.note(id)?.items?.first(where: { $0.id == item })?.body ?? ""
        editingItem = item
        sync.setEditingBody(item, in: id)
    }

    /// "Done", or the popover closing: stores the draft, then sends it.
    func endEditing() {
        guard let store, let sync, let id, let item = editingItem else { return }
        store.setItemBody(draft, item: item, for: id)
        editingItem = nil
        sync.setEditingBody(nil, in: id)
        sync.itemsChanged(id)
    }

    /// Closing the popover ends editing, so the change is sent.
    private func closed() {
        endEditing()
        popover = nil
        openItem = nil
    }

    nonisolated func popoverDidClose(_ notification: Notification) {
        MainActor.assumeIsolated {
            // A popover closed by `show` for another item is already done.
            guard (notification.object as? NSPopover) === popover else { return }
            closed()
        }
    }
}

/// Hosts a popover's content and tints the whole popover, its arrow
/// included, with the note's color, as `NoteBackground` tints the note.
/// The arrow belongs to the popover's frame view, outside the content, so
/// the tint goes there, below the content.
final class TintedPopoverController<Content: View>: NSHostingController<Content> {
    var tint: NSColor?
    private var tintView: NSView?

    override func viewDidAppear() {
        super.viewDidAppear()
        guard tintView == nil, let tint, let contentView = view.window?.contentView,
              let frameView = contentView.superview else { return }
        let tintView = NSView(frame: frameView.bounds)
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = tint.withAlphaComponent(tintStrength).cgColor
        tintView.autoresizingMask = [.width, .height]
        // Above the popover's material, which may be a sibling further down.
        frameView.addSubview(tintView, positioned: .below, relativeTo: contentView)
        self.tintView = tintView
    }
}

/// A linked row's description icon: a plain button that never takes
/// keyboard focus, so clicking it leaves the item being edited alone.
struct DescriptionButton: NSViewRepresentable {
    let controls: DescriptionControls
    let item: UUID

    final class FirstMouseButton: NSButton {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    func makeNSView(context: Context) -> NSButton {
        let button = FirstMouseButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        button.refusesFirstResponder = true
        button.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "Description")
        button.image?.isTemplate = true
        button.contentTintColor = .secondaryLabelColor
        button.setAccessibilityLabel("Description")
        button.toolTip = "Description (⌘D)"
        button.target = context.coordinator
        button.action = #selector(Coordinator.fire(_:))
        controls.register(button, for: item)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.action = { controls.toggle(item) }
        controls.register(nsView, for: item)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: { [controls, item] in controls.toggle(item) })
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func fire(_ sender: NSButton) { action() }
    }
}

/// The description popover: the description rendered as Markdown, with
/// "Edit" when the user may change the item. A held conflict shows
/// GitHub's description above, with "Keep mine" and "Use GitHub's".
struct DescriptionPopover: View {
    let store: NoteStore
    let sync: SyncController
    let id: UUID
    let itemID: UUID
    @ObservedObject var controls: DescriptionControls

    private var isEditing: Bool { controls.editingItem == itemID }

    private var item: ListItem? {
        store.note(id)?.items?.first(where: { $0.id == itemID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let item {
                Text(item.text.isEmpty ? "Untitled item" : item.text)
                    .font(.headline)
                    .lineLimit(2)
                if let held = item.heldBody {
                    conflict(held)
                }
                if isEditing {
                    TextEditor(text: $controls.draft)
                    .font(.body)
                    // The popover's own background, as in the view mode.
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 160, maxHeight: 320)
                } else {
                    ScrollView {
                        MarkdownView(text: item.body ?? "")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 320)
                }
                HStack {
                    Spacer()
                    if isEditing {
                        // No Return shortcut: Return types a new line.
                        Button("Done") { controls.endEditing() }
                    } else if sync.isEditable(item, in: id) {
                        Button("Edit") { controls.beginEditing(itemID) }
                    }
                }
            } else {
                Text("This item is no longer in the list.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 360)
    }

    private func conflict(_ held: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(SyncController.heldReason, systemImage: "exclamationmark.triangle")
                .font(.callout.bold())
            Text("GitHub's description:")
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView {
                MarkdownView(text: held)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxHeight: 160)
            HStack {
                Spacer()
                Button("Use GitHub's") { resolve(keepMine: false) }
                Button("Keep mine") { resolve(keepMine: true) }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.12)))
    }

    private func resolve(keepMine: Bool) {
        // "Use GitHub's" replaces the draft too, so "Done" keeps the choice.
        if !keepMine, isEditing, let held = item?.heldBody {
            controls.draft = held
        }
        store.resolveConflict(item: itemID, for: id, keepMine: keepMine)
        sync.itemsChanged(id)
    }
}
