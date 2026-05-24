import SwiftUI

struct EditFeedView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedURL: String
    @State private var feedName: String
    @State private var errorMessage = ""

    let feed: RSSFeedSource
    let onSave: (RSSFeedSource) -> Void

    init(feed: RSSFeedSource, onSave: @escaping (RSSFeedSource) -> Void) {
        self.feed = feed
        self.onSave = onSave
        _feedURL = State(initialValue: feed.url)
        _feedName = State(initialValue: feed.name)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Edit RSS Feed")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 8) {
                Text("Feed Name")
                    .font(.headline)
                TextField("e.g., Tech News", text: $feedName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Feed URL")
                    .font(.headline)
                TextField("https://example.com/rss", text: $feedURL)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    saveFeed()
                }
                .buttonStyle(.borderedProminent)
                .disabled(feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          feedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }

    private func saveFeed() {
        let trimmedURL = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = feedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedURL.isValidURL() else {
            errorMessage = "Please enter a valid URL"
            return
        }
        
        feed.url = trimmedURL
        feed.name = trimmedName
        onSave(feed)
        dismiss()
    }
}
