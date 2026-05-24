# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RSS Reader is a native macOS application built with Swift that provides RSS feed management through both a menu bar interface and a desktop window. The app uses SwiftUI for the UI layer and SwiftData for persistence.

## Build & Run Commands

```bash
# Build
xcodebuild build -scheme RSSReader -project RSSReader.xcodeproj

# Run tests (uses Swift Testing framework, not XCTest)
xcodebuild test -scheme RSSReader -project RSSReader.xcodeproj -destination 'platform=macOS'

# Run a single test by name
xcodebuild test -scheme RSSReader -project RSSReader.xcodeproj -destination 'platform=macOS' -only-testing:RSSReaderTests/RSSReaderTests/exampleTestName

# Open in Xcode
open RSSReader.xcodeproj

# Launch the built app
find ~/Library/Developer/Xcode/DerivedData -name "RSSReader.app" | head -n 1 | xargs open
```

**Test framework**: Tests use `import Testing` with `@Test` macro (Swift Testing), not XCTest.

## CI/CD Pipeline

### PR Validation (`.github/workflows/pr-check.yml`)
Triggers on PRs to `main` or `develop` — builds Debug, runs tests, posts status as PR comment.

### Automatic Release (`.github/workflows/release.yml`)
Triggers on push to `main` — auto-increments patch version, builds release (unsigned), creates DMG, publishes GitHub Release.

**Version Bumping**: PATCH auto-increments on every merge to `main`. To bump MAJOR/MINOR, push a tag manually before merging (`git tag v2.0.0 && git push --tags`).

### Development Workflow
1. Create feature branch from `develop`
2. Open PR to `develop` or `main`
3. CI validates automatically; merge to `main` triggers release

## Architecture

### Dual UI System
The app runs two interfaces simultaneously:
1. **Menu Bar** (`MenubarController` in `RSSReaderApp.swift`): Popover from the status bar icon
2. **Desktop Window** (`RSSReaderApp`): Standard `Window` scene

Each creates its own `ModelContainer`/`ModelContext` over the same SwiftData store. Changes persist through the shared on-disk store, but there is no real-time cross-context sync.

> Note: `MenubarController` declares `static let shared` but `AppDelegate` always creates a new instance via `MenubarController()` — the singleton is unused.

### Data Models (`RSSReader/Models/RSSmodel.swift`)
- **`RSSFeedItem`**: Article — title, link, pubDate (String), isRead, feedSourceURL/Name, `previewImageURL`. `itemDescription` uses `@Attribute(.externalStorage)` to store HTML blobs outside the main store file.
- **`RSSFeedSource`**: Feed subscription — name, URL, lastUpdated.
- **`DeletedArticle`**: Tombstone for deleted articles. `link` has `@Attribute(.unique)` — SwiftData enforces uniqueness at the store level.
- **`FilterOption`**: Enum (all/unread/read/feed) used for sidebar selection.

### State Management
`ContentViewModel` (MVVM, `@MainActor`) owns the `ModelContext` and centralises all CRUD, filtering, and refresh coordination. Views get it via `@StateObject`/`@ObservedObject`. Filtering is computed (`filteredFeedItems`) from in-memory arrays fetched by `fetchData()`.

### RSS Parsing (`Services/RSSParser.swift`)
Uses **callback-based concurrency** (`DispatchQueue` + completion handlers), not async/await — keep this pattern when extending it. Two-class design: `RSSParser` manages fetch tasks; `RSSParserDelegate` (NSXMLParserDelegate) accumulates parsed items, deduplicates against existing items and `DeletedArticle` tombstones, then batch-inserts in `parserDidEndDocument`.

Duplicate prevention runs in `parserDidEndDocument` against two sources:
1. Existing `RSSFeedItem` links
2. `DeletedArticle` links (prevents re-appearing deleted articles)

### String Extensions
String utilities are split across two files — both extend `String`:
- `String+Extensions.swift`: `strippingHTML()`
- `Data+Extensions.swift` (misleading name): `toDate()`, `formatAsRSSDate()`, `isValidURL()`, `extractDomain()`, `extractDomainName()`

### Menu Bar Integration
`MenubarController` uses `@AppStorage` for three persistent settings:
- `keepOpen` (Bool) — makes popover `.semitransient` instead of `.transient`
- `pollingInterval` (TimeInterval, default 300s) — controls the auto-refresh timer
- `showInMenuBar` (Bool) — switches app activation policy between `.regular` (dock visible) and `.accessory`

### Application Lifecycle
- `applicationShouldTerminateAfterLastWindowClosed` returns `false` — the app keeps running when the window is closed
- The desktop window hides itself on close (`windowShouldClose` calls `orderOut`) instead of terminating
- Default feed (joshwcomeau) is added on first launch if no feeds exist
