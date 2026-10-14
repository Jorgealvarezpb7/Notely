import Foundation

/// One block of a Markdown description. `text` is still Markdown for its
/// inline styles (bold, italic, code, links); the UI renders those.
public enum MarkdownBlock: Equatable {
    case heading(level: Int, text: String)
    case bullet(depth: Int, text: String)
    case numbered(depth: Int, number: Int, text: String)
    case task(depth: Int, checked: Bool, text: String)
    /// A fenced code block, shown as written.
    case code(language: String?, text: String)
    /// Consecutive other lines, joined by "\n" and kept as written. Tables,
    /// images, quotes, and HTML end up here.
    case paragraph(String)
}

/// Splits a description into the blocks a description popover renders:
/// headings, lists, task lists, fenced code, and paragraphs. A small
/// line-based subset of Markdown, not CommonMark: anything else stays a
/// paragraph, shown as written.
public enum MarkdownBlocks {
    public static func parse(_ text: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        // The open fence's language and lines, while inside one.
        var fence: (language: String?, lines: [String])?

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph = []
        }

        for line in IssueSync.normalizedBody(text).components(separatedBy: "\n") {
            let indent = indentWidth(line)
            let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })

            if let open = fence {
                if trimmed.hasPrefix("```") {
                    blocks.append(.code(language: open.language, text: open.lines.joined(separator: "\n")))
                    fence = nil
                } else {
                    fence?.lines.append(line)
                }
                continue
            }
            if trimmed.hasPrefix("```") {
                flushParagraph()
                let language = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                fence = (language.isEmpty ? nil : language, [])
                continue
            }
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }
            if let block = listOrHeading(trimmed, indent: indent) {
                flushParagraph()
                blocks.append(block)
                continue
            }
            paragraph.append(line)
        }
        flushParagraph()
        // An unclosed fence runs to the end, as on GitHub.
        if let open = fence {
            blocks.append(.code(language: open.language, text: open.lines.joined(separator: "\n")))
        }
        return blocks
    }

    /// Leading spaces, with a tab counted as 4.
    private static func indentWidth(_ line: String) -> Int {
        var width = 0
        for character in line {
            if character == " " { width += 1 } else if character == "\t" { width += 4 } else { break }
        }
        return width
    }

    private static func listOrHeading(_ line: Substring, indent: Int) -> MarkdownBlock? {
        let depth = indent / 2
        if indent <= 3, let heading = heading(line) {
            return heading
        }
        if let first = line.first, "-*+".contains(first), line.dropFirst().first == " " {
            let rest = line.dropFirst(2)
            if let (checked, text) = taskBox(rest) {
                return .task(depth: depth, checked: checked, text: text)
            }
            return .bullet(depth: depth, text: String(rest))
        }
        let digits = line.prefix(while: \.isASCIIDigit)
        if (1...9).contains(digits.count), let number = Int(digits) {
            let after = line.dropFirst(digits.count)
            if let marker = after.first, marker == "." || marker == ")", after.dropFirst().first == " " {
                return .numbered(depth: depth, number: number, text: String(after.dropFirst(2)))
            }
        }
        return nil
    }

    /// "# " to "###### ". A "#" with no space after it is not a heading.
    private static func heading(_ line: Substring) -> MarkdownBlock? {
        let hashes = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes) else { return nil }
        let rest = line.dropFirst(hashes)
        if rest.isEmpty { return .heading(level: hashes, text: "") }
        guard rest.first == " " else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        // A closing run of "#" after a space is not part of the text; the
        // "#" of "C#" is.
        let closing = text.reversed().prefix(while: { $0 == "#" }).count
        if closing > 0, closing == text.count || text.dropLast(closing).last == " " {
            text.removeLast(closing)
        }
        return .heading(level: hashes, text: text.trimmingCharacters(in: .whitespaces))
    }

    /// "[ ] text", "[x] text", or "[X] text", or the box alone.
    private static func taskBox(_ rest: Substring) -> (Bool, String)? {
        let box = rest.prefix(3)
        guard box == "[ ]" || box == "[x]" || box == "[X]" else { return nil }
        let after = rest.dropFirst(3)
        guard after.isEmpty || after.first == " " else { return nil }
        return (box != "[ ]", String(after.dropFirst()))
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
