//
//  ContentView.swift
//  RSSReader
//
//  Created by Alberto Barrago on 02/09/25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: ContentViewModel
    var style: ArticleListStyle

    init(modelContext: ModelContext, style: ArticleListStyle = .simple) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(modelContext: modelContext))
        self.style = style
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            MainContentView(viewModel: viewModel, style: style)
        }
        .frame(minWidth: 300, minHeight: 200)
        .sheet(isPresented: $viewModel.showingAddFeed) {
            AddFeedView { url, name in
                viewModel.addFeedSource(url: url, name: name)
            }
        }
        .sheet(isPresented: $viewModel.showingManageFeeds) {
            ManageFeedsView(viewModel: viewModel)
        }
        .sheet(item: $viewModel.feedToEdit) { feed in
            EditFeedView(feed: feed) { updatedFeed in
                viewModel.updateFeedSource(updatedFeed)
            }
        }
        .onAppear {
            if viewModel.feedSources.isEmpty {
                viewModel.addDefaultFeeds()
            }
        }
    }
}