import Testing
import SwiftData
@testable import RSSReader

@Suite("FilterOption")
@MainActor
struct FilterOptionTests {

    // MARK: - rawValue

    @Test func rawValue_all() {
        #expect(FilterOption.all.rawValue == "All")
    }

    @Test func rawValue_unread() {
        #expect(FilterOption.unread.rawValue == "Unread")
    }

    @Test func rawValue_read() {
        #expect(FilterOption.read.rawValue == "Read")
    }

    @Test func rawValue_feed() throws {
        let container = try makeInMemoryContainer()
        let source = RSSFeedSource(name: "TechCrunch", url: "https://techcrunch.com/feed/")
        container.mainContext.insert(source)
        #expect(FilterOption.feed(source).rawValue == "TechCrunch")
    }

    // MARK: - icon

    @Test func icon_all() {
        #expect(FilterOption.all.icon == "tray.full")
    }

    @Test func icon_unread() {
        #expect(FilterOption.unread.icon == "envelope.badge")
    }

    @Test func icon_read() {
        #expect(FilterOption.read.icon == "envelope.open")
    }

    @Test func icon_feed() throws {
        let container = try makeInMemoryContainer()
        let source = RSSFeedSource(name: "Feed", url: "https://example.com/rss")
        container.mainContext.insert(source)
        #expect(FilterOption.feed(source).icon == "newspaper")
    }

    // MARK: - Equality

    @Test func equality_allEqualsAll() {
        #expect(FilterOption.all == FilterOption.all)
    }

    @Test func equality_unreadEqualsUnread() {
        #expect(FilterOption.unread == FilterOption.unread)
    }

    @Test func equality_readEqualsRead() {
        #expect(FilterOption.read == FilterOption.read)
    }

    @Test func equality_differentCasesNotEqual() {
        #expect(FilterOption.all != FilterOption.unread)
        #expect(FilterOption.unread != FilterOption.read)
    }

    @Test func equality_feedWithSameSource() throws {
        let container = try makeInMemoryContainer()
        let source = RSSFeedSource(name: "Feed", url: "https://example.com/rss")
        container.mainContext.insert(source)
        #expect(FilterOption.feed(source) == FilterOption.feed(source))
    }

    @Test func equality_feedWithDifferentSources() throws {
        let container = try makeInMemoryContainer()
        let s1 = RSSFeedSource(name: "A", url: "https://a.com/rss")
        let s2 = RSSFeedSource(name: "B", url: "https://b.com/rss")
        container.mainContext.insert(s1)
        container.mainContext.insert(s2)
        #expect(FilterOption.feed(s1) != FilterOption.feed(s2))
    }

    @Test func equality_feedNotEqualToAll() throws {
        let container = try makeInMemoryContainer()
        let source = RSSFeedSource(name: "Feed", url: "https://example.com/rss")
        container.mainContext.insert(source)
        #expect(FilterOption.feed(source) != FilterOption.all)
    }

    // MARK: - Hashability

    @Test func hash_sameValuesProduceSameHash() {
        var h1 = Hasher(); FilterOption.all.hash(into: &h1)
        var h2 = Hasher(); FilterOption.all.hash(into: &h2)
        #expect(h1.finalize() == h2.finalize())
    }

    @Test func hash_differentValuesProduceDifferentHashes() {
        var h1 = Hasher(); FilterOption.all.hash(into: &h1)
        var h2 = Hasher(); FilterOption.unread.hash(into: &h2)
        #expect(h1.finalize() != h2.finalize())
    }

    // MARK: - allCases

    @Test func allCases_containsExactlyThreeStaticOptions() {
        let cases = FilterOption.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.all))
        #expect(cases.contains(.unread))
        #expect(cases.contains(.read))
    }
}

// MARK: - Helpers

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([RSSFeedSource.self, RSSFeedItem.self, DeletedArticle.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}
