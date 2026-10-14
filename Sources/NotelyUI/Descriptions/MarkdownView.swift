import NotelyCore
import SwiftUI

/// A description rendered from `MarkdownBlocks`: headings, lists, task
/// lists, and fenced code as blocks; bold, italic, inline code, and links
/// inside them from Foundation's inline Markdown. Task boxes only show
/// their state. Links open in the default browser.
struct MarkdownView: View {
    let text: String

    var body: some View {
        let blocks = MarkdownBlocks.parse(text)
        if blocks.isEmpty {
            Text("No description")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    view(block)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func view(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(Self.inline(text))
                .font(Self.headingFont(level))
                .padding(.top, level <= 2 ? 4 : 2)
        case .bullet(let depth, let text):
            listRow(depth: depth, marker: Text("•")) { Text(Self.inline(text)) }
        case .numbered(let depth, let number, let text):
            listRow(depth: depth, marker: Text("\(number).").monospacedDigit()) { Text(Self.inline(text)) }
        case .task(let depth, let checked, let text):
            listRow(depth: depth, marker: Text(Image(systemName: checked ? "checkmark.square" : "square"))) {
                Text(Self.inline(text))
            }
            .accessibilityLabel((checked ? "Done: " : "To do: ") + text)
        case .code(_, let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)))
        case .paragraph(let text):
            Text(Self.inline(text))
        }
    }

    private func listRow<Content: View>(depth: Int, marker: Text,
                                        @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            marker
                .foregroundStyle(.secondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.leading, CGFloat(depth) * 16)
    }

    private static func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        default: return .headline
        }
    }

    /// Bold, italic, inline code, and links; the text as written when it
    /// is not valid inline Markdown.
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
