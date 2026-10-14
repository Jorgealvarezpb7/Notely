import Foundation

/// One checklist item. A list's `items` are kept in display order: the
/// unchecked items, then the checked items, most recently checked first.
///
/// `issueNumber` is the GitHub issue the item stands for, on a list linked
/// to a repository. `nil` there means the issue is still to be created.
///
/// `remoteTitle`, `remoteClosed`, and `issueAuthor` are the issue as last
/// seen on GitHub. Where `text` or `done` differ from them, a change is
/// waiting to be sent (see `IssueSync.pendingChanges`).
///
/// `body` is the issue's description, in Markdown, and `remoteBody` the
/// description as last seen on GitHub. `heldBody` is GitHub's description
/// while a conflicting edit is held, `nil` otherwise.
public struct ListItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public var text: String
    public var done: Bool
    public var issueNumber: Int?
    public var remoteTitle: String?
    public var remoteClosed: Bool?
    public var issueAuthor: String?
    public var body: String?
    public var remoteBody: String?
    public var heldBody: String?

    public init(id: UUID, text: String, done: Bool, issueNumber: Int? = nil,
                remoteTitle: String? = nil, remoteClosed: Bool? = nil, issueAuthor: String? = nil,
                body: String? = nil, remoteBody: String? = nil, heldBody: String? = nil) {
        self.id = id
        self.text = text
        self.done = done
        self.issueNumber = issueNumber
        self.remoteTitle = remoteTitle
        self.remoteClosed = remoteClosed
        self.issueAuthor = issueAuthor
        self.body = body
        self.remoteBody = remoteBody
        self.heldBody = heldBody
    }
}

/// One styled range of a note's text. `location` and `length` count
/// UTF-16 code units, as `NSString` and `NSRange` do. A trait that is
/// `nil` is off.
public struct StyleRun: Codable, Equatable {
    public var location: Int
    public var length: Int
    public var bold: Bool?
    public var italic: Bool?
    public var underline: Bool?

    public init(location: Int, length: Int, bold: Bool? = nil, italic: Bool? = nil, underline: Bool? = nil) {
        self.location = location
        self.length = length
        self.bold = bold
        self.italic = italic
        self.underline = underline
    }

    /// The run trimmed to a text of `textLength` UTF-16 code units, or
    /// `nil` when nothing of it is left inside the text.
    public func clamped(toLength textLength: Int) -> StyleRun? {
        let start = max(location, 0)
        let end = min(location + length, textLength)
        guard end > start else { return nil }
        var run = self
        run.location = start
        run.length = end - start
        return run
    }
}

/// One note: its text and, once the window has been moved or resized,
/// its saved window position in `NSStringFromPoint` form and its saved
/// window size in `NSStringFromSize` form. `isOpen` is `false` once the
/// user closes the note's window with "−"; `nil` means open. All three are
/// optional, so notes saved by earlier versions still decode, and open.
///
/// A list is a note whose `kind` is "list", with a `title` and `items`.
/// `kind` is a string, not an enum, so a kind added by a later version
/// still decodes (as a note) instead of failing the whole saved list.
///
/// `styles` holds a note's bold, italic, and underlined ranges. `text`
/// stays plain, so a build without styles still shows the note's text.
///
/// `tint` is the note's color as sRGB "#RRGGBB", or nil for no tint.
///
/// `githubRepo` is the GitHub repository a list is linked to, as
/// "owner/repo", or nil for an unlinked list.
public struct Note: Codable, Identifiable {
    public let id: UUID
    public var text: String
    public var origin: String?
    public var size: String?
    public var isOpen: Bool?
    public var kind: String?
    public var title: String?
    public var items: [ListItem]?
    public var styles: [StyleRun]?
    public var tint: String?
    public var githubRepo: String?

    public static let listKind = "list"

    public var isList: Bool { kind == Self.listKind }

    public init(id: UUID, text: String, origin: String? = nil, size: String? = nil,
                isOpen: Bool? = nil, kind: String? = nil, title: String? = nil,
                items: [ListItem]? = nil, styles: [StyleRun]? = nil, tint: String? = nil,
                githubRepo: String? = nil) {
        self.id = id
        self.text = text
        self.origin = origin
        self.size = size
        self.isOpen = isOpen
        self.kind = kind
        self.title = title
        self.items = items
        self.styles = styles
        self.tint = tint
        self.githubRepo = githubRepo
    }
}

/// A list as plain text, written into `text` so a build without lists
/// shows the list's content as a readable note.
func plainText(ofList note: Note) -> String {
    ([note.title ?? ""] + (note.items ?? []).map { ($0.done ? "[x] " : "[ ] ") + $0.text })
        .joined(separator: "\n")
}
