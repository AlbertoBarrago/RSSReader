import Testing
import Foundation
@testable import RSSReader

@Suite("String Extensions")
struct StringExtensionsTests {

    // MARK: - strippingHTML

    @Test func strippingHTML_removesSimpleTags() {
        #expect("<p>Hello</p>".strippingHTML() == "Hello")
    }

    @Test func strippingHTML_removesNestedTags() {
        #expect("<div><span>World</span></div>".strippingHTML() == "World")
    }

    @Test func strippingHTML_removesTagsWithAttributes() {
        #expect("<a href=\"https://example.com\">Link</a>".strippingHTML() == "Link")
    }

    @Test func strippingHTML_leavesPlainTextUntouched() {
        #expect("No tags here".strippingHTML() == "No tags here")
    }

    @Test func strippingHTML_emptyStringReturnsEmpty() {
        #expect("".strippingHTML() == "")
    }

    // MARK: - isValidURL

    @Test func isValidURL_httpIsValid() {
        #expect("http://example.com".isValidURL() == true)
    }

    @Test func isValidURL_httpsIsValid() {
        #expect("https://example.com/path?q=1".isValidURL() == true)
    }

    @Test func isValidURL_ftpIsInvalid() {
        #expect("ftp://example.com".isValidURL() == false)
    }

    @Test func isValidURL_malformedStringIsInvalid() {
        #expect("not a url".isValidURL() == false)
    }

    @Test func isValidURL_emptyStringIsInvalid() {
        #expect("".isValidURL() == false)
    }

    // MARK: - extractDomain

    @Test func extractDomain_stripsWwwPrefix() {
        #expect("https://www.example.com/path".extractDomain() == "example.com")
    }

    @Test func extractDomain_leavesNonWwwDomainIntact() {
        #expect("https://blog.example.com".extractDomain() == "blog.example.com")
    }

    @Test func extractDomain_returnsHostForSimpleDomain() {
        #expect("https://example.com".extractDomain() == "example.com")
    }

    @Test func extractDomain_returnsInputForInvalidURL() {
        #expect("not-a-url".extractDomain() == "not-a-url")
    }

    // MARK: - extractDomainName

    @Test func extractDomainName_capitalizesSecondPartWhenWww() {
        #expect("https://www.github.com".extractDomainName() == "Github")
    }

    @Test func extractDomainName_capitalizesFirstPartForSubdomain() {
        #expect("https://blog.example.com".extractDomainName() == "Blog")
    }

    @Test func extractDomainName_returnsRSSFeedForInvalidURL() {
        #expect("bad-url".extractDomainName() == "RSS Feed")
    }

    // MARK: - toDate

    @Test func toDate_parsesRFC822Format() throws {
        let date = "Mon, 01 Jan 2024 12:00:00 +0000".toDate()
        #expect(date != nil)
    }

    @Test func toDate_parsesISO8601Format() throws {
        let date = "2024-01-01T12:00:00+0000".toDate()
        #expect(date != nil)
    }

    @Test func toDate_parsesISO8601WithMilliseconds() throws {
        let date = "2024-06-15T08:30:00.000+0000".toDate()
        #expect(date != nil)
    }

    @Test func toDate_parsesSpaceSeparatedFormat() throws {
        let date = "2024-01-01 12:00:00".toDate()
        #expect(date != nil)
    }

    @Test func toDate_returnsNilForGarbageString() {
        #expect("not a date".toDate() == nil)
    }

    @Test func toDate_returnsNilForEmptyString() {
        #expect("".toDate() == nil)
    }

    // MARK: - formatAsRSSDate

    @Test func formatAsRSSDate_returnsInputForUnparseableDate() {
        let raw = "garbage date string"
        #expect(raw.formatAsRSSDate() == raw)
    }

    @Test func formatAsRSSDate_prefixesTodayForTodayDate() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let todayString = formatter.string(from: Date())
        #expect(todayString.formatAsRSSDate().hasPrefix("Today"))
    }

    @Test func formatAsRSSDate_prefixesYesterdayForYesterdayDate() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let yesterdayString = formatter.string(from: yesterday)
        #expect(yesterdayString.formatAsRSSDate().hasPrefix("Yesterday"))
    }

    @Test func formatAsRSSDate_returnsMonthDayForOlderDate() {
        let old = "2020-03-15 10:00:00"
        let result = old.formatAsRSSDate()
        #expect(!result.hasPrefix("Today"))
        #expect(!result.hasPrefix("Yesterday"))
        #expect(result == "Mar 15")
    }
}
