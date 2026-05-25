import Testing
import SwiftData
@testable import RSSReader

@Suite("ContentViewModel")
@MainActor
struct ContentViewModelTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([RSSFeedSource.self, RSSFeedItem.self, DeletedArticle.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func makeItem(
        title: String = "Test Article",
        link: String = "https://example.com/article",
        isRead: Bool = false,
        feedSourceURL: String = "https://example.com/rss",
        feedSourceName: String = "Example"
    ) -> RSSFeedItem {
        let item = RSSFeedItem(title: title, link: link, pubDate: "2024-01-01 10:00:00",
                               feedSourceName: feedSourceName, feedSourceURL: feedSourceURL)
        item.isRead = isRead
        return item
    }

    // MARK: - Counts

    @Test func allCount_reflectsInsertedItems() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/1"))
        container.mainContext.insert(makeItem(link: "https://example.com/2"))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        #expect(vm.allCount == 2)
    }

    @Test func unreadCount_countsOnlyUnreadItems() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/read", isRead: true))
        container.mainContext.insert(makeItem(link: "https://example.com/unread", isRead: false))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        #expect(vm.unreadCount == 1)
        #expect(vm.readCount == 1)
    }

    // MARK: - filteredFeedItems

    @Test func filteredFeedItems_allReturnsEverything() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/1", isRead: true))
        container.mainContext.insert(makeItem(link: "https://example.com/2", isRead: false))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.selectedFilterIndex = 0
        vm.selectedFeedFilter = nil
        #expect(vm.filteredFeedItems.count == 2)
    }

    @Test func filteredFeedItems_unreadReturnsOnlyUnread() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/1", isRead: true))
        container.mainContext.insert(makeItem(link: "https://example.com/2", isRead: false))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.selectedFilterIndex = 1
        vm.selectedFeedFilter = nil
        let results = vm.filteredFeedItems
        #expect(results.count == 1)
        #expect(results.allSatisfy { !$0.isRead })
    }

    @Test func filteredFeedItems_readReturnsOnlyRead() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/1", isRead: true))
        container.mainContext.insert(makeItem(link: "https://example.com/2", isRead: false))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.selectedFilterIndex = 2
        vm.selectedFeedFilter = nil
        let results = vm.filteredFeedItems
        #expect(results.count == 1)
        #expect(results.allSatisfy { $0.isRead })
    }

    @Test func filteredFeedItems_feedFilterReturnsOnlyMatchingSource() throws {
        let container = try makeContainer()
        let source = RSSFeedSource(name: "Source A", url: "https://a.com/rss")
        container.mainContext.insert(source)
        container.mainContext.insert(makeItem(link: "https://example.com/1", feedSourceURL: "https://a.com/rss"))
        container.mainContext.insert(makeItem(link: "https://example.com/2", feedSourceURL: "https://b.com/rss"))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.selectedFeedFilter = source
        let results = vm.filteredFeedItems
        #expect(results.count == 1)
        #expect(results.first?.feedSourceURL == "https://a.com/rss")
    }

    // MARK: - Search

    @Test func filteredFeedItems_searchFiltersOnTitle_caseInsensitive() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(title: "Swift Concurrency Guide", link: "https://example.com/1"))
        container.mainContext.insert(makeItem(title: "Python Basics", link: "https://example.com/2"))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.selectedFilterIndex = 0
        vm.selectedFeedFilter = nil
        vm.searchText = "swift"
        #expect(vm.filteredFeedItems.count == 1)
        #expect(vm.filteredFeedItems.first?.title == "Swift Concurrency Guide")
    }

    @Test func filteredFeedItems_emptySearchReturnsAll() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/1"))
        container.mainContext.insert(makeItem(link: "https://example.com/2"))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.selectedFilterIndex = 0
        vm.selectedFeedFilter = nil
        vm.searchText = ""
        #expect(vm.filteredFeedItems.count == 2)
    }

    // MARK: - getFilterCount

    @Test func getFilterCount_returnsNilWhenZero() throws {
        let container = try makeContainer()
        let vm = ContentViewModel(modelContext: container.mainContext)
        #expect(vm.getFilterCount(for: .all) == nil)
        #expect(vm.getFilterCount(for: .unread) == nil)
        #expect(vm.getFilterCount(for: .read) == nil)
    }

    @Test func getFilterCount_returnsCountWhenNonZero() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/1", isRead: false))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        #expect(vm.getFilterCount(for: .all) == 1)
        #expect(vm.getFilterCount(for: .unread) == 1)
        #expect(vm.getFilterCount(for: .read) == nil)
    }

    @Test func getFilterCount_feedAlwaysReturnsNil() throws {
        let container = try makeContainer()
        let source = RSSFeedSource(name: "Feed", url: "https://example.com/rss")
        container.mainContext.insert(source)
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        #expect(vm.getFilterCount(for: .feed(source)) == nil)
    }

    // MARK: - isFilterSelected

    @Test func isFilterSelected_matchesCurrentFilter() throws {
        let container = try makeContainer()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.selectedFilterIndex = 0
        vm.selectedFeedFilter = nil
        #expect(vm.isFilterSelected(.all) == true)
        #expect(vm.isFilterSelected(.unread) == false)
    }

    // MARK: - addFeedSource

    @Test func addFeedSource_preventsDuplicateURL() throws {
        let container = try makeContainer()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.addFeedSource(url: "https://example.com/rss", name: "Example")
        vm.addFeedSource(url: "https://example.com/rss", name: "Duplicate")
        #expect(vm.feedSources.count == 1)
    }

    @Test func addFeedSource_trimsWhitespace() throws {
        let container = try makeContainer()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.addFeedSource(url: "  https://example.com/rss  ", name: "  Feed  ")
        #expect(vm.feedSources.first?.url == "https://example.com/rss")
        #expect(vm.feedSources.first?.name == "Feed")
    }

    // MARK: - markAsRead / toggleReadStatus

    @Test func markAsRead_setsItemRead() throws {
        let container = try makeContainer()
        let item = makeItem(link: "https://example.com/1", isRead: false)
        container.mainContext.insert(item)
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.markAsRead(item)
        #expect(item.isRead == true)
    }

    @Test func toggleReadStatus_flipsRead() throws {
        let container = try makeContainer()
        let item = makeItem(link: "https://example.com/1", isRead: false)
        container.mainContext.insert(item)
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.toggleReadStatus(item)
        #expect(item.isRead == true)
        vm.toggleReadStatus(item)
        #expect(item.isRead == false)
    }

    // MARK: - markAllAsRead

    @Test func markAllAsRead_marksAllFilteredItemsAsRead() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/1", isRead: false))
        container.mainContext.insert(makeItem(link: "https://example.com/2", isRead: false))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.selectedFilterIndex = 0
        vm.selectedFeedFilter = nil
        vm.markAllAsRead()
        vm.fetchData()
        #expect(vm.unreadCount == 0)
    }

    // MARK: - archiveAndDelete / tombstone

    @Test func archiveAndDelete_removesItemFromContext() throws {
        let container = try makeContainer()
        let item = makeItem(link: "https://example.com/to-delete")
        container.mainContext.insert(item)
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.archiveAndDelete(items: [item])
        vm.fetchData()
        #expect(vm.allCount == 0)
    }

    @Test func archiveAndDelete_createsTombstone() throws {
        let container = try makeContainer()
        let item = makeItem(link: "https://example.com/deleted-link")
        container.mainContext.insert(item)
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.archiveAndDelete(items: [item])
        let tombstones = try container.mainContext.fetch(FetchDescriptor<DeletedArticle>())
        #expect(tombstones.contains { $0.link == "https://example.com/deleted-link" })
    }

    @Test func archiveAndDelete_noopOnEmptyArray() throws {
        let container = try makeContainer()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.archiveAndDelete(items: []) // should not crash
        #expect(vm.allCount == 0)
    }

    // MARK: - cleanReadItems

    @Test func cleanReadItems_removesOnlyReadItems() throws {
        let container = try makeContainer()
        container.mainContext.insert(makeItem(link: "https://example.com/read", isRead: true))
        container.mainContext.insert(makeItem(link: "https://example.com/unread", isRead: false))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        vm.cleanReadItems()
        vm.fetchData()
        #expect(vm.allCount == 1)
        #expect(vm.allFeedItems.first?.isRead == false)
    }

    // MARK: - unreadCount(for:)

    @Test func unreadCountForFeed_countsCorrectly() throws {
        let container = try makeContainer()
        let source = RSSFeedSource(name: "Feed A", url: "https://a.com/rss")
        container.mainContext.insert(source)
        container.mainContext.insert(makeItem(link: "https://example.com/1", isRead: false, feedSourceURL: "https://a.com/rss"))
        container.mainContext.insert(makeItem(link: "https://example.com/2", isRead: true, feedSourceURL: "https://a.com/rss"))
        container.mainContext.insert(makeItem(link: "https://example.com/3", isRead: false, feedSourceURL: "https://b.com/rss"))
        try container.mainContext.save()
        let vm = ContentViewModel(modelContext: container.mainContext)
        #expect(vm.unreadCount(for: source) == 1)
    }
}
