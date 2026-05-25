import SwiftData
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var feedSources: [RSSFeedSource] = []
    @Published var allFeedItems: [RSSFeedItem] = []
    @Published var showingAddFeed = false
    @Published var showingManageFeeds = false
    @Published var selectedFilterIndex: Int = 0
    @Published var selectedFeedFilter: RSSFeedSource? = nil
    @Published var feedToEdit: RSSFeedSource? = nil
    @Published var searchText = ""

    @Published private(set) var isLoading = false

    var modelContext: ModelContext
    private let parser = RSSParser()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchData()
    }

    func fetchData() {
        do {
            let feedSourcesDescriptor = FetchDescriptor<RSSFeedSource>(sortBy: [SortDescriptor(\RSSFeedSource.name)])
            let allFeedItemsDescriptor = FetchDescriptor<RSSFeedItem>(sortBy: [SortDescriptor(\RSSFeedItem.pubDate, order: .reverse)])
            feedSources = try modelContext.fetch(feedSourcesDescriptor)
            allFeedItems = try modelContext.fetch(allFeedItemsDescriptor)
        } catch {
            print("Error fetching data: \(error)")
        }
    }

    var filteredFeedItems: [RSSFeedItem] {
        let filteredBySelection = switch selectedFilter {
        case .all:
            allFeedItems
        case .unread:
            allFeedItems.filter { !$0.isRead }
        case .read:
            allFeedItems.filter { $0.isRead }
        case .feed(let feedSource):
            allFeedItems.filter { $0.feedSourceURL == feedSource.url }
        }
        
        if searchText.isEmpty {
            return filteredBySelection
        } else {
            return filteredBySelection.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    func getFilterCount(for filter: FilterOption) -> Int? {
        switch filter {
        case .all:
            return allCount > 0 ? allCount : nil
        case .unread:
            return unreadCount > 0 ? unreadCount : nil
        case .read:
            return readCount > 0 ? readCount : nil
        case .feed:
            return nil
        }
    }
    
    var selectedFilter: FilterOption {
        if let feedFilter = selectedFeedFilter {
            return .feed(feedFilter)
        }
        return FilterOption.allCases[selectedFilterIndex]
    }
    
    func isFilterSelected(_ filter: FilterOption) -> Bool {
        switch (selectedFilter, filter) {
        case (.all, .all), (.unread, .unread), (.read, .read):
            return true
        case (.feed(let selectedFeed), .feed(let filterFeed)):
            return selectedFeed.id == filterFeed.id
        default:
            return false
        }
    }

    var unreadCount: Int {
        allFeedItems.filter { !$0.isRead }.count
    }

    var readCount: Int {
        allFeedItems.filter { $0.isRead }.count
    }

    var allCount: Int {
        allFeedItems.count
    }

    func unreadCount(for feedSource: RSSFeedSource) -> Int {
        allFeedItems.filter { $0.feedSourceURL == feedSource.url && !$0.isRead }.count
    }

    func addDefaultFeeds() {
        let defaultFeeds = [
            RSSFeedSource(name: "joshwcomeau", url: "https://www.joshwcomeau.com/rss.xml")
        ]

        for feed in defaultFeeds {
            modelContext.insert(feed)
        }
        try? modelContext.save()
        fetchData()
    }

    func addFeedSource(url: String, name: String) {
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !feedSources.contains(where: { $0.url == trimmedURL }) else { return }
        let newFeed = RSSFeedSource(name: name.trimmingCharacters(in: .whitespacesAndNewlines), url: trimmedURL)
        
        modelContext.insert(newFeed)
        try? modelContext.save()
        fetchData()
        isLoading = true
        parser.fetchFeed(from: newFeed, in: modelContext) { [weak self] in
            self?.isLoading = false
        }
    }

    func updateFeedSource(_ feed: RSSFeedSource) {
        try? modelContext.save()
        fetchData()
    }

    func archiveAndDelete(items: [RSSFeedItem]) {
        guard !items.isEmpty else { return }

        do {
            let linksToArchive = Set(items.map { $0.link })

            let existingDeletedDescriptor = FetchDescriptor<DeletedArticle>(
                predicate: #Predicate { linksToArchive.contains($0.link) }
            )
            let existingDeletedLinks = try Set(modelContext.fetch(existingDeletedDescriptor).map { $0.link })

            for link in linksToArchive where !existingDeletedLinks.contains(link) {
                let newDeletedArticle = DeletedArticle(link: link)
                modelContext.insert(newDeletedArticle)
            }

            for item in items {
                modelContext.delete(item)
            }

            try modelContext.save()
            fetchData()
        } catch {
            print("Error during archive and delete: \(error)")
        }
    }
    
    func deleteFeed(_ feed: RSSFeedSource) {
        do {
            let feedURL = feed.url
            let itemsToDelete = try modelContext.fetch(FetchDescriptor<RSSFeedItem>(predicate: #Predicate { $0.feedSourceURL == feedURL }))
            archiveAndDelete(items: itemsToDelete)

            modelContext.delete(feed)
            try modelContext.save()
            fetchData()
        } catch {
            print("Error deleting feed and its items: \(error)")
        }
    }

    func refreshCurrentFilter() {
        switch selectedFilter {
        case .feed(let feedSource):
            isLoading = true
            parser.fetchFeed(from: feedSource, in: modelContext) {
                self.fetchData()
                self.isLoading = false
            }
        default:
            refreshAllFeeds()
        }
    }

    func refreshAllFeeds() {
        isLoading = true
        parser.refreshAllFeeds(sources: feedSources, in: modelContext) {
            self.fetchData()
            self.isLoading = false
        }
    }

    func markAsRead(_ item: RSSFeedItem) {
        item.isRead = true
        try? modelContext.save()
        fetchData()
    }

    func toggleReadStatus(_ item: RSSFeedItem) {
        item.isRead.toggle()
        try? modelContext.save()
        fetchData()
    }

    func markAllAsRead() {
        for item in filteredFeedItems where !item.isRead {
            item.isRead = true
        }
        try? modelContext.save()
        fetchData()
    }

    func cleanReadItems() {
        do {
            let itemsToClean = try modelContext.fetch(FetchDescriptor<RSSFeedItem>(predicate: #Predicate { $0.isRead }))
            archiveAndDelete(items: itemsToClean)

        } catch {
            print("Error finding read items to clean: \(error)")
        }
    }

    func cleanOldItems() {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let oldItems = allFeedItems.filter {
            guard let itemDate = $0.pubDate.toDate() else { return false }
            return itemDate < thirtyDaysAgo
        }

        archiveAndDelete(items: oldItems)
    }

    func deleteItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredFeedItems[$0] }
        archiveAndDelete(items: itemsToDelete)
    }

    func clearAllFeedItems() {
        do {
            let allItems = try modelContext.fetch(FetchDescriptor<RSSFeedItem>())
            archiveAndDelete(items: allItems)

        } catch {
            print("Error fetching all items to clear: \(error)")
        }
    }
}
