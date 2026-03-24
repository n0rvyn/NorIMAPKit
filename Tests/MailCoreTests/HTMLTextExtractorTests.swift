// HTMLTextExtractorTests.swift
// swift-mail-core — Tests for DOM-based HTML text extraction

import Testing
import Foundation
@testable import MailCore

@Suite("HTMLTextExtractor")
struct HTMLTextExtractorTests {

    @Test("Extracts heading as markdown")
    func headingExtraction() {
        let html = "<html><body><h1>Welcome</h1><p>Hello world</p></body></html>"
        let text = HTMLTextExtractor.extractStructuredText(html: html)
        #expect(text.contains("## Welcome"))
        #expect(text.contains("Hello world"))
    }

    @Test("Extracts unordered list items")
    func unorderedList() {
        let html = "<ul><li>Apple</li><li>Banana</li><li>Cherry</li></ul>"
        let text = HTMLTextExtractor.extractStructuredText(html: html)
        #expect(text.contains("- Apple"))
        #expect(text.contains("- Banana"))
        #expect(text.contains("- Cherry"))
    }

    @Test("Extracts ordered list items")
    func orderedList() {
        let html = "<ol><li>First</li><li>Second</li><li>Third</li></ol>"
        let text = HTMLTextExtractor.extractStructuredText(html: html)
        #expect(text.contains("1. First"))
        #expect(text.contains("2. Second"))
        #expect(text.contains("3. Third"))
    }

    @Test("Extracts link with URL")
    func linkExtraction() {
        let html = "<p>Visit <a href=\"https://example.com\">our site</a> today</p>"
        let text = HTMLTextExtractor.extractStructuredText(html: html)
        #expect(text.contains("our site (https://example.com)"))
    }

    @Test("Extracts table as pipe-delimited")
    func tableExtraction() {
        let html = """
        <table>
            <tr><th>Name</th><th>Age</th></tr>
            <tr><td>Alice</td><td>30</td></tr>
            <tr><td>Bob</td><td>25</td></tr>
        </table>
        """
        let text = HTMLTextExtractor.extractStructuredText(html: html)
        #expect(text.contains("| Name"))
        #expect(text.contains("| Alice"))
        #expect(text.contains("| Bob"))
    }

    @Test("Removes script and style elements")
    func removesScriptsAndStyles() {
        let html = """
        <html><body>
        <script>alert('xss')</script>
        <style>.hidden { display: none; }</style>
        <p>Visible content</p>
        </body></html>
        """
        let text = HTMLTextExtractor.extractStructuredText(html: html)
        #expect(!text.contains("alert"))
        #expect(!text.contains("hidden"))
        #expect(text.contains("Visible content"))
    }

    @Test("Handles empty HTML")
    func emptyHTML() {
        #expect(HTMLTextExtractor.extractStructuredText(html: "").isEmpty)
    }

    @Test("Extracts image alt text")
    func imageAltText() {
        let html = "<p>See <img alt=\"company logo\" src=\"logo.png\"> here</p>"
        let text = HTMLTextExtractor.extractStructuredText(html: html)
        #expect(text.contains("[Image: company logo]"))
    }
}
