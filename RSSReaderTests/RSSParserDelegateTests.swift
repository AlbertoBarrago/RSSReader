import Testing
import Foundation
import SwiftData
@testable import RSSReader

@Suite("RSSParserDelegate")
@MainActor
struct RSSParserDelegateTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([RSSFeedSource.self, RSSFeedItem.self, DeletedArticle.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeSource(name: String = "Test Feed", url: String = "https://example.com/rss") -> RSSFeedSource {
        RSSFeedSource(name: name, url: url)
    }

    /// Parses `xml` synchronously and drains the main queue so `parserDidEndDocument` can complete.
    private func parse(xml: String, source: RSSFeedSource, context: ModelContext) async {
        let data = Data(xml.utf8)
        let parser = XMLParser(data: data)
        let delegate = RSSParserDelegate(feedSource: source, modelContext: context)
        parser.delegate = delegate
        parser.parse()
        // parserDidEndDocument dispatches to DispatchQueue.main.async;
        // yielding the main actor lets that block run before we inspect state.
        await Task.yield()
        await Task.yield()
    }

    private func fetchItems(from context: ModelContext) throws -> [RSSFeedItem] {
        try context.fetch(FetchDescriptor<RSSFeedItem>())
    }

    // MARK: - RSS 2.0

    @Test func rss2_parsesValidFeed() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>First Article</title>
              <link>https://example.com/first</link>
              <pubDate>Mon, 01 Jan 2024 10:00:00 +0000</pubDate>
              <description>Some content here.</description>
            </item>
            <item>
              <title>Second Article</title>
              <link>https://example.com/second</link>
              <pubDate>Tue, 02 Jan 2024 10:00:00 +0000</pubDate>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.count == 2)
        #expect(items.contains { $0.title == "First Article" })
        #expect(items.contains { $0.title == "Second Article" })
    }

    @Test func rss2_storesFeedSourceMetadata() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Article</title>
              <link>https://example.com/article</link>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource(name: "My Blog", url: "https://myblog.com/rss")
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.first?.feedSourceName == "My Blog")
        #expect(items.first?.feedSourceURL == "https://myblog.com/rss")
    }

    @Test func rss2_itemWithoutTitleIsSkipped() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <link>https://example.com/no-title</link>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.isEmpty)
    }

    @Test func rss2_itemWithoutLinkIsSkipped() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>No Link Article</title>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.isEmpty)
    }

    // MARK: - Atom

    @Test func atom_parsesValidFeed() async throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <title>Atom Article</title>
            <link rel="alternate" href="https://example.com/atom-article"/>
            <published>2024-01-01T10:00:00+0000</published>
            <summary>Summary text.</summary>
          </entry>
        </feed>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.count == 1)
        #expect(items.first?.title == "Atom Article")
        #expect(items.first?.link == "https://example.com/atom-article")
    }

    // MARK: - Duplicate prevention

    @Test func duplicatePrevention_existingLinkNotReinserted() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Existing Article</title>
              <link>https://example.com/existing</link>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        // Pre-insert an item with the same link
        let existing = RSSFeedItem(title: "Existing Article", link: "https://example.com/existing",
                                   pubDate: "2024-01-01 10:00:00", feedSourceName: "Test Feed",
                                   feedSourceURL: "https://example.com/rss")
        container.mainContext.insert(existing)
        try container.mainContext.save()
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.count == 1)
    }

    @Test func tombstonePrevention_deletedLinkNotReinserted() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Deleted Article</title>
              <link>https://example.com/deleted</link>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        // Pre-insert a tombstone for this link
        let tombstone = DeletedArticle(link: "https://example.com/deleted")
        container.mainContext.insert(tombstone)
        try container.mainContext.save()
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.isEmpty)
    }

    // MARK: - Image extraction

    @Test func imageExtraction_fromEnclosure() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Article with Image</title>
              <link>https://example.com/article</link>
              <enclosure url="https://example.com/image.jpg" type="image/jpeg"/>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.first?.previewImageURL == "https://example.com/image.jpg")
    }

    @Test func imageExtraction_fromMediaContent() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
          <channel>
            <item>
              <title>Article with Media</title>
              <link>https://example.com/article</link>
              <media:content url="https://example.com/media.png" medium="image"/>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.first?.previewImageURL == "https://example.com/media.png")
    }

    @Test func imageExtraction_fallbackFromDescriptionImgTag() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Article with Inline Image</title>
              <link>https://example.com/article</link>
              <description>&lt;p&gt;Text &lt;img src="https://example.com/inline.jpg" /&gt;&lt;/p&gt;</description>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.first?.previewImageURL == "https://example.com/inline.jpg")
    }

    @Test func imageExtraction_noneWhenNoImagePresent() async throws {
        let xml = """
        <?xml version="1.0"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Text-only Article</title>
              <link>https://example.com/article</link>
              <description>Just plain text, no images.</description>
            </item>
          </channel>
        </rss>
        """
        let container = try makeContainer()
        let source = makeSource()
        container.mainContext.insert(source)
        await parse(xml: xml, source: source, context: container.mainContext)
        let items = try fetchItems(from: container.mainContext)
        #expect(items.first?.previewImageURL == nil)
    }
}
