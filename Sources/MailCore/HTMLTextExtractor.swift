// HTMLTextExtractor.swift
// swift-mail-core — DOM-based HTML → structured plain text conversion
//
// Uses SwiftSoup for DOM parsing. Converts HTML email bodies into
// structured plain text suitable for LLM processing.
//
// Coexists with RFC2822Decoder.stripHTMLTags() which provides a
// zero-dependency regex fallback.

import Foundation
import SwiftSoup

public nonisolated enum HTMLTextExtractor {

    /// Converts HTML to structured plain text for LLM consumption.
    ///
    /// Preserves semantic structure:
    /// - Headings → `## Heading`
    /// - Lists → `- item`
    /// - Tables → pipe-delimited rows
    /// - Links → `text (url)`
    /// - Images → `[Image: alt]`
    ///
    /// Removes scripts, styles, and hidden elements.
    public static func extractStructuredText(html: String) -> String {
        guard !html.isEmpty else { return "" }

        do {
            let doc = try SwiftSoup.parse(html)

            // Remove non-content elements
            try doc.select("script, style, noscript").remove()
            try doc.select("[style*=display:none], [style*=display: none]").remove()
            try doc.select("[style*=visibility:hidden], [style*=visibility: hidden]").remove()
            try doc.select("[hidden]").remove()

            guard let body = doc.body() else {
                return try doc.text()
            }

            var lines: [String] = []
            traverseNode(body, into: &lines)

            let result = lines.joined(separator: "\n")

            // Collapse 3+ newlines to 2
            let collapsed = result.replacingOccurrences(
                of: #"\n{3,}"#, with: "\n\n",
                options: .regularExpression
            )

            return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            // SwiftSoup parse failure — fall back to basic text extraction
            return html.replacingOccurrences(
                of: #"<[^>]+>"#, with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Private DOM Traversal

    private static func traverseNode(_ node: Node, into lines: inout [String]) {
        for child in node.getChildNodes() {
            if let textNode = child as? TextNode {
                let text = textNode.getWholeText()
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
                if !text.isEmpty {
                    appendText(text, to: &lines)
                }
            } else if let element = child as? Element {
                handleElement(element, into: &lines)
            }
        }
    }

    private static func handleElement(_ element: Element, into lines: inout [String]) {
        let tag = element.tagName().lowercased()

        switch tag {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let text = (try? element.text()) ?? ""
            if !text.isEmpty {
                lines.append("")
                lines.append("## \(text)")
                lines.append("")
            }

        case "p", "div", "article", "section", "header", "footer", "main":
            lines.append("")
            traverseNode(element, into: &lines)
            lines.append("")

        case "br":
            lines.append("")

        case "ul", "ol":
            lines.append("")
            handleList(element, into: &lines)
            lines.append("")

        case "li":
            let text = (try? element.text()) ?? ""
            if !text.isEmpty {
                lines.append("- \(text)")
            }

        case "table":
            lines.append("")
            handleTable(element, into: &lines)
            lines.append("")

        case "a":
            let text = (try? element.text()) ?? ""
            let href = (try? element.attr("href")) ?? ""
            if !text.isEmpty && !href.isEmpty && href != text {
                appendText("\(text) (\(href))", to: &lines)
            } else if !text.isEmpty {
                appendText(text, to: &lines)
            }

        case "img":
            let alt = (try? element.attr("alt")) ?? ""
            if !alt.isEmpty {
                appendText("[Image: \(alt)]", to: &lines)
            }

        case "blockquote":
            lines.append("")
            let text = (try? element.text()) ?? ""
            if !text.isEmpty {
                for line in text.components(separatedBy: "\n") {
                    lines.append("> \(line)")
                }
            }
            lines.append("")

        case "pre", "code":
            let text = (try? element.text()) ?? ""
            if !text.isEmpty {
                lines.append("")
                lines.append("```")
                lines.append(text)
                lines.append("```")
                lines.append("")
            }

        case "hr":
            lines.append("")
            lines.append("---")
            lines.append("")

        case "strong", "b":
            let text = (try? element.text()) ?? ""
            if !text.isEmpty {
                appendText("**\(text)**", to: &lines)
            }

        case "em", "i":
            let text = (try? element.text()) ?? ""
            if !text.isEmpty {
                appendText("*\(text)*", to: &lines)
            }

        default:
            traverseNode(element, into: &lines)
        }
    }

    private static func handleList(_ listElement: Element, into lines: inout [String]) {
        let items = (try? listElement.select("> li")) ?? Elements()
        for (index, item) in items.array().enumerated() {
            let text = (try? item.text()) ?? ""
            if !text.isEmpty {
                if listElement.tagName().lowercased() == "ol" {
                    lines.append("\(index + 1). \(text)")
                } else {
                    lines.append("- \(text)")
                }
            }
        }
    }

    private static func handleTable(_ table: Element, into lines: inout [String]) {
        let rows = (try? table.select("tr")) ?? Elements()

        var tableData: [[String]] = []
        for row in rows.array() {
            let cells = (try? row.select("th, td")) ?? Elements()
            let cellTexts = cells.array().compactMap { try? $0.text() }
            if !cellTexts.isEmpty {
                tableData.append(cellTexts)
            }
        }

        guard !tableData.isEmpty else { return }

        // Calculate column widths
        let colCount = tableData.map(\.count).max() ?? 0
        var widths = [Int](repeating: 0, count: colCount)
        for row in tableData {
            for (i, cell) in row.enumerated() where i < colCount {
                widths[i] = max(widths[i], cell.count)
            }
        }

        // Format rows
        for (rowIndex, row) in tableData.enumerated() {
            var cells: [String] = []
            for i in 0..<colCount {
                let text = i < row.count ? row[i] : ""
                cells.append(text.padding(toLength: widths[i], withPad: " ", startingAt: 0))
            }
            lines.append("| " + cells.joined(separator: " | ") + " |")

            // Add separator after header row
            if rowIndex == 0 {
                let separators = widths.map { String(repeating: "-", count: $0) }
                lines.append("| " + separators.joined(separator: " | ") + " |")
            }
        }
    }

    private static func appendText(_ text: String, to lines: inout [String]) {
        if let last = lines.last, !last.isEmpty {
            lines[lines.count - 1] = last + " " + text
        } else {
            lines.append(text)
        }
    }
}
