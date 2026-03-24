// MIMEDecoderBodiesTests.swift
// swift-mail-core — Tests for RFC2822Decoder.extractBodies()

import Testing
import Foundation
@testable import MailCore

@Suite("RFC2822Decoder.extractBodies")
struct ExtractBodiesTests {

    @Test("Simple text/plain returns text only")
    func simplePlainText() {
        let message = """
        From: test@example.com\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        Hello, this is plain text.
        """
        let result = RFC2822Decoder.extractBodies(message)
        #expect(result.text.contains("Hello, this is plain text."))
        #expect(result.html == nil)
    }

    @Test("Simple text/html returns both text and html")
    func simpleHTML() {
        let message = """
        From: test@example.com\r
        Content-Type: text/html; charset=utf-8\r
        \r
        <html><body><p>Hello world</p></body></html>
        """
        let result = RFC2822Decoder.extractBodies(message)
        #expect(result.text.contains("Hello world"))
        #expect(result.html != nil)
        #expect(result.html!.contains("<p>Hello world</p>"))
    }

    @Test("Multipart/alternative returns plain text and html")
    func multipartAlternative() {
        let message = """
        From: test@example.com\r
        Content-Type: multipart/alternative; boundary="boundary123"\r
        \r
        --boundary123\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        Plain text version\r
        --boundary123\r
        Content-Type: text/html; charset=utf-8\r
        \r
        <html><body><p>HTML version</p></body></html>\r
        --boundary123--
        """
        let result = RFC2822Decoder.extractBodies(message)
        #expect(result.text.contains("Plain text version"))
        #expect(result.html != nil)
        #expect(result.html!.contains("<p>HTML version</p>"))
    }

    @Test("Nested multipart extracts correctly")
    func nestedMultipart() {
        let message = """
        From: test@example.com\r
        Content-Type: multipart/mixed; boundary="outer"\r
        \r
        --outer\r
        Content-Type: multipart/alternative; boundary="inner"\r
        \r
        --inner\r
        Content-Type: text/plain; charset=utf-8\r
        \r
        Nested plain text\r
        --inner\r
        Content-Type: text/html; charset=utf-8\r
        \r
        <p>Nested HTML</p>\r
        --inner--\r
        --outer--
        """
        let result = RFC2822Decoder.extractBodies(message)
        #expect(result.text.contains("Nested plain text"))
        #expect(result.html != nil)
    }

    @Test("Empty body returns empty")
    func emptyBody() {
        let message = "From: test@example.com\r\n\r\n"
        let result = RFC2822Decoder.extractBodies(message)
        #expect(result.text.isEmpty)
        #expect(result.html == nil)
    }

    @Test("HTML-only multipart uses HTMLTextExtractor for text")
    func htmlOnlyMultipart() {
        let message = """
        From: test@example.com\r
        Content-Type: multipart/alternative; boundary="b1"\r
        \r
        --b1\r
        Content-Type: text/html; charset=utf-8\r
        \r
        <html><body><h1>Title</h1><p>Content</p></body></html>\r
        --b1--
        """
        let result = RFC2822Decoder.extractBodies(message)
        // When only HTML is available, text should be extracted via HTMLTextExtractor
        #expect(result.text.contains("Title"))
        #expect(result.text.contains("Content"))
        #expect(result.html != nil)
    }
}
