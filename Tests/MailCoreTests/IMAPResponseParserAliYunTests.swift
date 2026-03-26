// IMAPResponseParserAliYunTests.swift
// swift-mail-core — Tests for non-Gmail IMAP server responses (AliYun, Outlook, etc.)

import Testing
import Foundation
@testable import MailCore

// MARK: - LIST Response Edge Cases

@Suite("IMAPResponseParser — LIST Edge Cases")
struct ListEdgeCaseTests {

    @Test("Parses LIST with empty flags ()")
    func parseListEmptyFlags() {
        let folder = IMAPResponseParser.parseListResponse(#"* LIST () "/" "INBOX""#)
        #expect(folder != nil)
        #expect(folder?.name == "INBOX")
        #expect(folder?.delimiter == "/")
        #expect(folder?.flags == [])
    }

    @Test("Parses LIST with AliYun modified UTF-7 Trash folder")
    func parseListAliYunTrash() {
        let folder = IMAPResponseParser.parseListResponse(#"* LIST (\Trash) "/" "&XfJSIJZkkK5O9g-""#)
        #expect(folder != nil)
        #expect(folder?.name == "&XfJSIJZkkK5O9g-")
        #expect(folder?.flags == ["\\Trash"])
    }

    @Test("Parses LIST with AliYun modified UTF-7 Drafts folder")
    func parseListAliYunDrafts() {
        let folder = IMAPResponseParser.parseListResponse(#"* LIST (\Drafts) "/" "&g0l6Pw-""#)
        #expect(folder != nil)
        #expect(folder?.name == "&g0l6Pw-")
        #expect(folder?.flags == ["\\Drafts"])
    }

    @Test("Parses LIST with AliYun modified UTF-7 Sent folder")
    func parseListAliYunSent() {
        let folder = IMAPResponseParser.parseListResponse(#"* LIST (\Sent) "/" "&XfJT0ZAB-""#)
        #expect(folder != nil)
        #expect(folder?.name == "&XfJT0ZAB-")
        #expect(folder?.flags == ["\\Sent"])
    }

    @Test("Parses LIST with AliYun Junk folder")
    func parseListAliYunJunk() {
        let folder = IMAPResponseParser.parseListResponse(#"* LIST (\Junk) "/" "&V4NXPpCuTvY-""#)
        #expect(folder != nil)
        #expect(folder?.name == "&V4NXPpCuTvY-")
    }

    @Test("Parses LIST with Outlook-style folder names")
    func parseListOutlookSent() {
        let folder = IMAPResponseParser.parseListResponse(#"* LIST (\Sent \HasNoChildren) "/" "Sent Items""#)
        #expect(folder != nil)
        #expect(folder?.name == "Sent Items")
        #expect(folder?.flags.contains("\\Sent") == true)
    }

    @Test("Parses LIST with dot delimiter (Dovecot)")
    func parseListDotDelimiter() {
        let folder = IMAPResponseParser.parseListResponse(#"* LIST (\HasNoChildren) "." "INBOX.Sent""#)
        #expect(folder != nil)
        #expect(folder?.name == "INBOX.Sent")
        #expect(folder?.delimiter == ".")
    }

    @Test("Parses LIST with NIL delimiter")
    func parseListNilDelimiter() {
        let folder = IMAPResponseParser.parseListResponse(#"* LIST (\Noselect) NIL "INBOX""#)
        #expect(folder != nil)
        #expect(folder?.name == "INBOX")
        #expect(folder?.delimiter == "")
    }
}

// MARK: - BODYSTRUCTURE with Extension Data

@Suite("IMAPResponseParser — BODYSTRUCTURE Extension Data")
struct BodyStructureExtensionTests {

    @Test("Parses AliYun multipart/alternative with extension data")
    func parseAliYunMultipartAlternative() {
        let line = """
        * 1 FETCH (UID 1 BODYSTRUCTURE (("text" "plain" ("charset" "UTF-8") NIL NIL "base64" 1234 16 NIL NIL NIL)("text" "html" ("charset" "UTF-8") NIL NIL "base64" 4486 58 NIL NIL NIL) "alternative" ("boundary" "----=ALIBOUNDARY_2800") NIL NIL))
        """
        let part = IMAPResponseParser.parseBodyStructure(line)
        #expect(part != nil)
        if case .multipart(let parts, let subtype) = part {
            #expect(subtype == "alternative")
            #expect(parts.count == 2)
            if case .singlePart(let type, let subtype, let encoding, let size, let path, _, let charset) = parts[0] {
                #expect(type == "text")
                #expect(subtype == "plain")
                #expect(encoding == "base64")
                #expect(size == 1234)
                #expect(path == "1")
                #expect(charset == "utf-8")
            } else {
                Issue.record("Expected singlePart for part 0")
            }
            if case .singlePart(let type, let subtype, _, _, let path, _, _) = parts[1] {
                #expect(type == "text")
                #expect(subtype == "html")
                #expect(path == "2")
            } else {
                Issue.record("Expected singlePart for part 1")
            }
        } else {
            Issue.record("Expected multipart")
        }
    }

    @Test("Parses single part with 11 tokens (RFC 3501 text extension)")
    func parseSinglePartWithExtensionData() {
        let line = """
        * 1 FETCH (UID 42 BODYSTRUCTURE ("text" "plain" ("charset" "UTF-8") NIL NIL "quoted-printable" 2048 55 NIL NIL NIL))
        """
        let part = IMAPResponseParser.parseBodyStructure(line)
        #expect(part != nil)
        if case .singlePart(let type, let subtype, let encoding, let size, let path, _, let charset) = part {
            #expect(type == "text")
            #expect(subtype == "plain")
            #expect(encoding == "quoted-printable")
            #expect(size == 2048)
            #expect(path == "1")
            #expect(charset == "utf-8")
        } else {
            Issue.record("Expected singlePart")
        }
    }

    @Test("Parses nested multipart/mixed containing multipart/alternative")
    func parseNestedMultipart() {
        let line = """
        * 1 FETCH (UID 10 BODYSTRUCTURE ((("text" "plain" ("charset" "utf-8") NIL NIL "7bit" 500 10)("text" "html" ("charset" "utf-8") NIL NIL "7bit" 1500 30) "alternative")("application" "pdf" ("name" "doc.pdf") NIL NIL "base64" 50000) "mixed"))
        """
        let part = IMAPResponseParser.parseBodyStructure(line)
        #expect(part != nil)
        if case .multipart(let parts, let subtype) = part {
            #expect(subtype == "mixed")
            #expect(parts.count == 2)
            // First part is multipart/alternative
            if case .multipart(let innerParts, let innerSubtype) = parts[0] {
                #expect(innerSubtype == "alternative")
                #expect(innerParts.count == 2)
            } else {
                Issue.record("Expected inner multipart")
            }
            // Second part is application/pdf
            if case .singlePart(let type, _, _, _, _, let filename, _) = parts[1] {
                #expect(type == "application")
                #expect(filename == "doc.pdf")
            } else {
                Issue.record("Expected singlePart for PDF")
            }
        } else {
            Issue.record("Expected multipart")
        }
    }
}

// MARK: - Envelope Edge Cases

@Suite("IMAPResponseParser — Envelope Edge Cases")
struct EnvelopeEdgeCaseTests {

    @Test("Parses envelope with RFC2047 multi-word subject")
    func parseEnvelopeRFC2047MultiWord() {
        let lines = [
            """
            * 5 FETCH (UID 5 FLAGS () INTERNALDATE "26-Mar-2026 15:26:11 +0800" ENVELOPE ("Thu, 26 Mar 2026 15:26:00 +0800" "=?utf-8?Q?Fwd=3A_=F0=9F=8D=8B=C2=A0From_film-first_branding_to_Sp?= =?utf-8?Q?rite=E2=80=99s_refreshing_refresh?=" (("ZHANG ZHIJIE" NIL "norvyn" "norvyn.com")) (("ZHANG ZHIJIE" NIL "norvyn" "norvyn.com")) (("ZHANG ZHIJIE" NIL "norvyn" "norvyn.com")) ((NIL NIL "test" "norvyn.com")) NIL NIL NIL "<D6BE50A7-A2B4-478D-A2AC-19B1E5A747F7@norvyn.com>"))
            """
        ]
        let msg = IMAPResponseParser.parseFetchEnvelope(lines: lines)
        #expect(msg != nil)
        #expect(msg?.uid == 5)
        // Subject should contain the decoded emoji and full text
        #expect(msg?.subject.contains("Fwd:") == true)
        #expect(msg?.subject.contains("refreshing refresh") == true)
        #expect(msg?.isSeen == false)
        #expect(msg?.messageId == "<D6BE50A7-A2B4-478D-A2AC-19B1E5A747F7@norvyn.com>")
    }

    @Test("Parses envelope with NIL sender display name")
    func parseEnvelopeNilSenderName() {
        let lines = [
            """
            * 1 FETCH (UID 1 FLAGS (\\Seen) INTERNALDATE "26-Mar-2026 10:00:00 +0800" ENVELOPE ("Thu, 26 Mar 2026 10:00:00 +0800" "Test subject" ((NIL NIL "user" "example.com")) ((NIL NIL "user" "example.com")) ((NIL NIL "user" "example.com")) ((NIL NIL "recipient" "example.com")) NIL NIL NIL "<msg@example.com>"))
            """
        ]
        let msg = IMAPResponseParser.parseFetchEnvelope(lines: lines)
        #expect(msg != nil)
        #expect(msg?.sender == "user@example.com")
        #expect(msg?.to == "recipient@example.com")
    }

    @Test("Parses INTERNALDATE with positive timezone offset")
    func parseInternalDatePositiveOffset() {
        let lines = [
            """
            * 1 FETCH (UID 1 FLAGS () INTERNALDATE "26-Mar-2026 15:26:11 +0800" ENVELOPE ("26 Mar 2026 15:26:11 +0800" "Test" ((NIL NIL "a" "b.com")) ((NIL NIL "a" "b.com")) ((NIL NIL "a" "b.com")) ((NIL NIL "c" "d.com")) NIL NIL NIL "<id@b.com>"))
            """
        ]
        let msg = IMAPResponseParser.parseFetchEnvelope(lines: lines)
        #expect(msg != nil)
        #expect(msg?.internalDate != nil)
    }

    @Test("Parses envelope with multiple To recipients")
    func parseEnvelopeMultipleTo() {
        let lines = [
            """
            * 1 FETCH (UID 1 FLAGS () INTERNALDATE "01-Jan-2026 00:00:00 +0000" ENVELOPE ("1 Jan 2026 00:00:00 +0000" "Multi-to" (("Sender" NIL "sender" "a.com")) (("Sender" NIL "sender" "a.com")) (("Sender" NIL "sender" "a.com")) (("User A" NIL "a" "x.com")("User B" NIL "b" "x.com")) NIL NIL NIL "<id@a.com>"))
            """
        ]
        let msg = IMAPResponseParser.parseFetchEnvelope(lines: lines)
        #expect(msg != nil)
        #expect(msg?.to.contains("a@x.com") == true)
        #expect(msg?.to.contains("b@x.com") == true)
    }

    @Test("Parses envelope with multiple Cc recipients")
    func parseEnvelopeMultipleCc() {
        let lines = [
            """
            * 1 FETCH (UID 1 FLAGS () INTERNALDATE "01-Jan-2026 00:00:00 +0000" ENVELOPE ("1 Jan 2026 00:00:00 +0000" "Multi-cc" (("S" NIL "s" "a.com")) (("S" NIL "s" "a.com")) (("S" NIL "s" "a.com")) ((NIL NIL "to" "a.com")) (("CC1" NIL "cc1" "a.com")("CC2" NIL "cc2" "a.com")) NIL NIL "<id@a.com>"))
            """
        ]
        let msg = IMAPResponseParser.parseFetchEnvelope(lines: lines)
        #expect(msg != nil)
        #expect(msg?.cc.contains("cc1@a.com") == true)
        #expect(msg?.cc.contains("cc2@a.com") == true)
    }

    @Test("Parses envelope with empty (No Subject)")
    func parseEnvelopeNoSubject() {
        let lines = [
            """
            * 1 FETCH (UID 99 FLAGS () INTERNALDATE "01-Jan-2026 00:00:00 +0000" ENVELOPE ("1 Jan 2026 00:00:00 +0000" NIL (("S" NIL "s" "a.com")) (("S" NIL "s" "a.com")) (("S" NIL "s" "a.com")) ((NIL NIL "to" "a.com")) NIL NIL NIL "<id@a.com>"))
            """
        ]
        let msg = IMAPResponseParser.parseFetchEnvelope(lines: lines)
        #expect(msg != nil)
        #expect(msg?.subject == "(No Subject)")
    }

    @Test("Parses envelope with GB2312 encoded subject")
    func parseEnvelopeGB2312Subject() {
        // =?GB2312?B?... is common in Chinese email
        let lines = [
            """
            * 1 FETCH (UID 1 FLAGS () INTERNALDATE "01-Jan-2026 00:00:00 +0000" ENVELOPE ("1 Jan 2026 00:00:00 +0000" "=?GB2312?B?xOO6w6Os?=" (("S" NIL "s" "a.com")) (("S" NIL "s" "a.com")) (("S" NIL "s" "a.com")) ((NIL NIL "to" "a.com")) NIL NIL NIL "<id@a.com>"))
            """
        ]
        let msg = IMAPResponseParser.parseFetchEnvelope(lines: lines)
        #expect(msg != nil)
        // GB2312 "你好，" should decode
        #expect(msg?.subject.isEmpty == false)
        #expect(msg?.subject != "(No Subject)")
    }

    @Test("Parses date with parenthesised timezone comment")
    func parseDateWithTimezoneComment() {
        let lines = [
            """
            * 1 FETCH (UID 1 FLAGS () INTERNALDATE "01-Jan-2026 00:00:00 +0000" ENVELOPE ("Wed, 01 Jan 2026 00:00:00 +0000 (UTC)" "Test" (("S" NIL "s" "a.com")) (("S" NIL "s" "a.com")) (("S" NIL "s" "a.com")) ((NIL NIL "to" "a.com")) NIL NIL NIL "<id@a.com>"))
            """
        ]
        let msg = IMAPResponseParser.parseFetchEnvelope(lines: lines)
        #expect(msg != nil)
        #expect(msg?.date != Date())
    }
}

// MARK: - Tagged Response Edge Cases

@Suite("IMAPResponseParser — Tagged Response Edge Cases")
struct TaggedResponseEdgeCaseTests {

    @Test("Parses OK with bracketed response code")
    func parseTaggedWithBracketedCode() {
        let result = IMAPResponseParser.parseTagged("A003 OK [READ-WRITE] SELECT completed")
        #expect(result != nil)
        #expect(result?.status == .ok)
        #expect(result?.text.contains("[READ-WRITE]") == true)
    }

    @Test("Parses tag with numeric prefix")
    func parseNumericTag() {
        let result = IMAPResponseParser.parseTagged("1 OK Done")
        #expect(result != nil)
        #expect(result?.tag == "1")
        #expect(result?.status == .ok)
    }
}

// MARK: - UID SEARCH Edge Cases

@Suite("IMAPResponseParser — UID SEARCH Edge Cases")
struct SearchEdgeCaseTests {

    @Test("Parses SEARCH with large UIDs")
    func parseSearchLargeUIDs() {
        let uids = IMAPResponseParser.parseSearchUIDs("* SEARCH 4294967295")
        #expect(uids == [4294967295])
    }

    @Test("Parses SEARCH with single UID")
    func parseSearchSingleUID() {
        let uids = IMAPResponseParser.parseSearchUIDs("* SEARCH 42")
        #expect(uids == [42])
    }
}
