import Foundation
import NotelyCore
import Testing

struct MarkdownBlocksTests {
    @Test func headingsOneToSix() {
        #expect(MarkdownBlocks.parse("# A\n###### F\n####### G") == [
            .heading(level: 1, text: "A"),
            .heading(level: 6, text: "F"),
            .paragraph("####### G"),
        ])
    }

    @Test func hashWithoutSpaceIsAParagraph() {
        #expect(MarkdownBlocks.parse("#tag") == [.paragraph("#tag")])
    }

    @Test func closingHashesGoButCSharpStays() {
        #expect(MarkdownBlocks.parse("## Steps ##\n# C#") == [
            .heading(level: 2, text: "Steps"),
            .heading(level: 1, text: "C#"),
        ])
    }

    @Test func bulletsWithDepth() {
        #expect(MarkdownBlocks.parse("- a\n* b\n  + c") == [
            .bullet(depth: 0, text: "a"),
            .bullet(depth: 0, text: "b"),
            .bullet(depth: 1, text: "c"),
        ])
    }

    @Test func numberedItems() {
        #expect(MarkdownBlocks.parse("1. one\n2) two") == [
            .numbered(depth: 0, number: 1, text: "one"),
            .numbered(depth: 0, number: 2, text: "two"),
        ])
    }

    @Test func taskItems() {
        #expect(MarkdownBlocks.parse("- [ ] fix\n- [x] repro\n  * [X] nested") == [
            .task(depth: 0, checked: false, text: "fix"),
            .task(depth: 0, checked: true, text: "repro"),
            .task(depth: 1, checked: true, text: "nested"),
        ])
    }

    @Test func linkTextIsNotATask() {
        #expect(MarkdownBlocks.parse("- [docs](https://example.com)") == [
            .bullet(depth: 0, text: "[docs](https://example.com)"),
        ])
    }

    @Test func fencedCodeWithLanguage() {
        #expect(MarkdownBlocks.parse("```swift\nlet a = 1\n# not a heading\n```\nafter") == [
            .code(language: "swift", text: "let a = 1\n# not a heading"),
            .paragraph("after"),
        ])
    }

    @Test func unclosedFenceRunsToTheEnd() {
        #expect(MarkdownBlocks.parse("```\n- a") == [.code(language: nil, text: "- a")])
    }

    @Test func tableAndImageStayAsWritten() {
        let table = "| a | b |\n|---|---|\n| 1 | 2 |"
        #expect(MarkdownBlocks.parse(table + "\n\n![shot](x.png)") == [
            .paragraph(table),
            .paragraph("![shot](x.png)"),
        ])
    }

    @Test func blankLinesSplitParagraphsAndCollapse() {
        #expect(MarkdownBlocks.parse("a\nb\n\n\n\nc\r\n") == [
            .paragraph("a\nb"),
            .paragraph("c"),
        ])
    }

    @Test func horizontalRuleIsAParagraph() {
        #expect(MarkdownBlocks.parse("---") == [.paragraph("---")])
    }

    @Test func emptyIsNoBlocks() {
        #expect(MarkdownBlocks.parse("").isEmpty)
    }
}
