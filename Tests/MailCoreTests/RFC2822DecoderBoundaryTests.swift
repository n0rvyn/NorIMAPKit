// RFC2822DecoderBoundaryTests.swift
// swift-mail-core — Tests for boundary case-sensitivity fix and multipart decoding

import Testing
import Foundation
@testable import MailCore

// MARK: - Boundary Case-Sensitivity

@Suite("RFC2822Decoder — Boundary Case-Sensitivity")
struct BoundaryCaseSensitivityTests {

    @Test("Extracts text from multipart with uppercase boundary (AliYun)")
    func uppercaseBoundary() {
        let message = """
        Content-Type: multipart/alternative;\r
         boundary="----=ALIBOUNDARY_2800_ABC123"\r
        \r
        ------=ALIBOUNDARY_2800_ABC123\r
        Content-Type: text/plain; charset="UTF-8"\r
        Content-Transfer-Encoding: 7bit\r
        \r
        Hello from AliYun\r
        ------=ALIBOUNDARY_2800_ABC123\r
        Content-Type: text/html; charset="UTF-8"\r
        Content-Transfer-Encoding: 7bit\r
        \r
        <p>Hello from AliYun</p>\r
        ------=ALIBOUNDARY_2800_ABC123--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("Hello from AliYun"))
    }

    @Test("Extracts text from multipart with mixed-case boundary (Apple Mail)")
    func mixedCaseBoundary() {
        let message = """
        Content-Type: multipart/alternative;\r
         boundary="Apple-Mail=_AD8EB017-4D44-4CAE-A22D-9440C3365C2D"\r
        \r
        --Apple-Mail=_AD8EB017-4D44-4CAE-A22D-9440C3365C2D\r
        Content-Type: text/plain; charset=utf-8\r
        Content-Transfer-Encoding: 7bit\r
        \r
        Apple Mail content\r
        --Apple-Mail=_AD8EB017-4D44-4CAE-A22D-9440C3365C2D\r
        Content-Type: text/html; charset=utf-8\r
        Content-Transfer-Encoding: 7bit\r
        \r
        <p>Apple Mail content</p>\r
        --Apple-Mail=_AD8EB017-4D44-4CAE-A22D-9440C3365C2D--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("Apple Mail content"))
    }

    @Test("extractBodies preserves case-sensitive boundary")
    func extractBodiesCaseSensitiveBoundary() {
        let message = """
        Content-Type: multipart/alternative;\r
         boundary="----=ALIBOUNDARY_XYZ"\r
        \r
        ------=ALIBOUNDARY_XYZ\r
        Content-Type: text/plain; charset="UTF-8"\r
        Content-Transfer-Encoding: 7bit\r
        \r
        Plain text here\r
        ------=ALIBOUNDARY_XYZ\r
        Content-Type: text/html; charset="UTF-8"\r
        Content-Transfer-Encoding: 7bit\r
        \r
        <html><body><p>HTML here</p></body></html>\r
        ------=ALIBOUNDARY_XYZ--
        """
        let result = RFC2822Decoder.extractBodies(message)
        #expect(result.text.contains("Plain text here"))
        #expect(result.html != nil)
        #expect(result.html!.contains("<p>HTML here</p>"))
    }

    @Test("Nested multipart with case-sensitive boundary")
    func nestedMultipartCaseSensitive() {
        let message = """
        Content-Type: multipart/mixed;\r
         boundary="OuterBOUNDARY_123"\r
        \r
        --OuterBOUNDARY_123\r
        Content-Type: multipart/alternative;\r
         boundary="InnerBOUNDARY_456"\r
        \r
        --InnerBOUNDARY_456\r
        Content-Type: text/plain; charset=utf-8\r
        Content-Transfer-Encoding: 7bit\r
        \r
        Nested plain text\r
        --InnerBOUNDARY_456\r
        Content-Type: text/html; charset=utf-8\r
        Content-Transfer-Encoding: 7bit\r
        \r
        <p>Nested HTML</p>\r
        --InnerBOUNDARY_456--\r
        --OuterBOUNDARY_123--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("Nested plain text"))
    }
}

// MARK: - Base64 Body Decoding

@Suite("RFC2822Decoder — Base64 Body Decoding")
struct Base64BodyDecodingTests {

    @Test("Decodes base64-encoded text/plain part")
    func base64PlainText() {
        // "Hello World" in base64
        let message = """
        Content-Type: text/plain; charset=UTF-8\r
        Content-Transfer-Encoding: base64\r
        \r
        SGVsbG8gV29ybGQ=
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text == "Hello World")
    }

    @Test("Decodes base64-encoded Chinese text")
    func base64ChineseText() {
        // "你好世界" in base64
        let base64 = Data("你好世界".utf8).base64EncodedString()
        let message = """
        Content-Type: text/plain; charset=UTF-8\r
        Content-Transfer-Encoding: base64\r
        \r
        \(base64)
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text == "你好世界")
    }

    @Test("Decodes multipart with base64 text/plain (AliYun style)")
    func multipartBase64AliYunStyle() {
        let plainBase64 = Data("亲爱的用户您好".utf8).base64EncodedString()
        let htmlBase64 = Data("<p>亲爱的用户您好</p>".utf8).base64EncodedString()

        let message = """
        Content-Type: multipart/alternative;\r
         boundary="----=ALIBOUNDARY_TEST"\r
        \r
        ------=ALIBOUNDARY_TEST\r
        Content-Type: text/plain; charset="UTF-8"\r
        Content-Transfer-Encoding: base64\r
        \r
        \(plainBase64)\r
        ------=ALIBOUNDARY_TEST\r
        Content-Type: text/html; charset="UTF-8"\r
        Content-Transfer-Encoding: base64\r
        \r
        \(htmlBase64)\r
        ------=ALIBOUNDARY_TEST--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("亲爱的用户您好"))
    }

    @Test("extractBodies with base64 multipart returns both text and html")
    func extractBodiesBase64Multipart() {
        let plainBase64 = Data("Plain content".utf8).base64EncodedString()
        let htmlBase64 = Data("<html><body><p>HTML content</p></body></html>".utf8).base64EncodedString()

        let message = """
        Content-Type: multipart/alternative;\r
         boundary="----=BOUNDARY"\r
        \r
        ------=BOUNDARY\r
        Content-Type: text/plain; charset="UTF-8"\r
        Content-Transfer-Encoding: base64\r
        \r
        \(plainBase64)\r
        ------=BOUNDARY\r
        Content-Type: text/html; charset="UTF-8"\r
        Content-Transfer-Encoding: base64\r
        \r
        \(htmlBase64)\r
        ------=BOUNDARY--
        """
        let result = RFC2822Decoder.extractBodies(message)
        #expect(result.text.contains("Plain content"))
        #expect(result.html != nil)
        #expect(result.html!.contains("<p>HTML content</p>"))
    }
}

// MARK: - Quoted-Printable Body Decoding

@Suite("RFC2822Decoder — Quoted-Printable Body Decoding")
struct QuotedPrintableBodyDecodingTests {

    @Test("Decodes quoted-printable text/plain")
    func qpPlainText() {
        let message = """
        Content-Type: text/plain; charset=utf-8\r
        Content-Transfer-Encoding: quoted-printable\r
        \r
        Hello=20World=0D=0ALine two
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("Hello World"))
        #expect(text.contains("Line two"))
    }

    @Test("Decodes multipart with quoted-printable parts")
    func multipartQP() {
        let message = """
        Content-Type: multipart/alternative;\r
         boundary="Apple-Mail=_TEST"\r
        \r
        --Apple-Mail=_TEST\r
        Content-Type: text/plain; charset=utf-8\r
        Content-Transfer-Encoding: quoted-printable\r
        \r
        QP plain =E2=9C=93\r
        --Apple-Mail=_TEST\r
        Content-Type: text/html; charset=utf-8\r
        Content-Transfer-Encoding: quoted-printable\r
        \r
        <p>QP html =E2=9C=93</p>\r
        --Apple-Mail=_TEST--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        // =E2=9C=93 is UTF-8 for ✓
        #expect(text.contains("QP plain"))
    }
}

// MARK: - Charset Handling

@Suite("RFC2822Decoder — Charset Handling")
struct CharsetHandlingTests {

    @Test("Decodes Windows-1252 encoded body")
    func windows1252Body() {
        let message = """
        Content-Type: text/plain; charset=windows-1252\r
        Content-Transfer-Encoding: 7bit\r
        \r
        Hello World
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text == "Hello World")
    }

    @Test("Maps charset names correctly")
    func charsetMapping() {
        #expect(Data.stringEncoding(fromCharset: "utf-8") == .utf8)
        #expect(Data.stringEncoding(fromCharset: "UTF-8") == .utf8)
        #expect(Data.stringEncoding(fromCharset: "utf8") == .utf8)
        #expect(Data.stringEncoding(fromCharset: "us-ascii") == .ascii)
        #expect(Data.stringEncoding(fromCharset: "ascii") == .ascii)
        #expect(Data.stringEncoding(fromCharset: "iso-8859-1") == .isoLatin1)
        #expect(Data.stringEncoding(fromCharset: "windows-1252") == .windowsCP1252)
        #expect(Data.stringEncoding(fromCharset: "cp1252") == .windowsCP1252)
        #expect(Data.stringEncoding(fromCharset: "shift_jis") == .shiftJIS)
        #expect(Data.stringEncoding(fromCharset: "shift-jis") == .shiftJIS)
        #expect(Data.stringEncoding(fromCharset: "iso-2022-jp") == .iso2022JP)
    }
}

// MARK: - Header Parsing Edge Cases

@Suite("RFC2822Decoder — Header Parsing")
struct HeaderParsingTests {

    @Test("Extracts Content-Type with tab continuation")
    func contentTypeWithTabContinuation() {
        let message = """
        From: test@example.com\r
        Content-Type: multipart/alternative;\r
        \tboundary="TestBoundary"\r
        \r
        --TestBoundary\r
        Content-Type: text/plain\r
        \r
        Content here\r
        --TestBoundary--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("Content here"))
    }

    @Test("Extracts Content-Type with space continuation")
    func contentTypeWithSpaceContinuation() {
        let message = """
        From: test@example.com\r
        Content-Type: multipart/alternative;\r
          boundary="TestBoundary2"\r
        \r
        --TestBoundary2\r
        Content-Type: text/plain\r
        \r
        Space continuation content\r
        --TestBoundary2--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("Space continuation content"))
    }

    @Test("Handles message with no Content-Type (defaults to text/plain)")
    func noContentType() {
        let message = """
        From: test@example.com\r
        Subject: Simple\r
        \r
        Just plain text
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text == "Just plain text")
    }
}

// MARK: - RFC 2047 Decoder Additional Tests

@Suite("RFC2047Decoder — Additional Edge Cases")
struct RFC2047AdditionalTests {

    @Test("Decodes multiple adjacent Q-encoded words")
    func multipleQEncodedWords() {
        let input = "=?UTF-8?Q?Hello_?= =?UTF-8?Q?World?="
        let decoded = RFC2047Decoder.decode(input)
        #expect(decoded == "Hello World")
    }

    @Test("Decodes mixed encoded and plain text")
    func mixedEncodedAndPlain() {
        let input = "Re: =?UTF-8?B?5rWL6K+V?= message"
        let decoded = RFC2047Decoder.decode(input)
        #expect(decoded == "Re: 测试 message")
    }

    @Test("Handles case-insensitive encoding flag")
    func caseInsensitiveEncoding() {
        let input = "=?utf-8?b?5rWL6K+V?="
        let decoded = RFC2047Decoder.decode(input)
        #expect(decoded == "测试")
    }

    @Test("Handles lowercase charset")
    func lowercaseCharset() {
        let input = "=?utf-8?B?SGVsbG8=?="
        let decoded = RFC2047Decoder.decode(input)
        #expect(decoded == "Hello")
    }
}

// MARK: - Boundary Extraction Edge Cases

@Suite("RFC2822Decoder — Boundary Extraction")
struct BoundaryExtractionTests {

    @Test("Extracts boundary with equals sign")
    func boundaryWithEquals() {
        let message = """
        Content-Type: multipart/alternative;\r
         boundary="----=_Part_123"\r
        \r
        ------=_Part_123\r
        Content-Type: text/plain\r
        \r
        Content\r
        ------=_Part_123--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("Content"))
    }

    @Test("Extracts unquoted boundary")
    func unquotedBoundary() {
        let message = """
        Content-Type: multipart/alternative; boundary=simple_boundary_123\r
        \r
        --simple_boundary_123\r
        Content-Type: text/plain\r
        \r
        Unquoted boundary content\r
        --simple_boundary_123--
        """
        let text = RFC2822Decoder.extractTextBody(message)
        #expect(text.contains("Unquoted boundary content"))
    }
}
