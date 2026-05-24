# RSS Reader

[![GitHub last commit](https://img.shields.io/github/last-commit/AlbertoBarrago/RSS-Reader)](https://github.com/AlbertoBarrago/RSS-Reader/commits/main)
[![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/AlbertoBarrago/RSS-Reader)](https://github.com/AlbertoBarrago/RSS-Reader/releases/latest)
[![GitHub repo size](https://img.shields.io/github/repo-size/AlbertoBarrago/RSS-Reader)](https://github.com/AlbertoBarrago/RSS-Reader)
[![GitHub stars](https://img.shields.io/github/stars/AlbertoBarrago/RSS-Reader?style=social)](https://github.com/AlbertoBarrago/RSS-Reader/stargazers)

A lightweight, native macOS RSS Reader application built with Swift. Stay up-to-date with your favorite news sources, blogs, and websites through a clean, intuitive interface that lives in your menu bar.

![RSS Reader Screenshot](screen.png)

## Features

- 📰 **Clean Interface**: Minimalist design focused on readability
- ⚡ **Menu Bar Integration**: Quick access without cluttering your dock
- 🔄 **Real-time Updates**: Automatically fetches the latest articles
- 🎯 **Native macOS**: Built specifically for macOS using Swift
- 💾 **Lightweight**: Minimal resource usage and fast performance

## Requirements

- macOS 14.0+ (Sonoma or later)
- Xcode 15.0+ (for building from source)

## Installation

### Download Pre-built App (Recommended)

1. **Download the latest release:**
   - Go to [Releases](https://github.com/AlbertoBarrago/RSS-Reader/releases/latest)
   - Download `RSSReader-X.X.X.dmg`

2. **Install the app:**
   - Open the downloaded DMG file
   - Drag `RSSReader.app` to your Applications folder
   - **Do NOT open the app yet**

3. **⚠️ Important: Bypass macOS Gatekeeper (Required for unsigned apps)**

   Since the app is not code-signed, macOS will block it with a "damaged" error. To fix this, open Terminal and run:

   ```bash
   xattr -cr /Applications/RSSReader.app
   ```

   **What this does:** Removes the quarantine flag that macOS applies to downloaded apps.

   **Alternative method** (may not work on all macOS versions):
   - Right-click `RSSReader.app` in Applications
   - Select "Open"
   - Click "Open" again in the security dialog

4. **Launch the app:**
   - Now you can open RSS Reader from Applications or Spotlight
   - The app will appear in your menu bar

> **Note:** This is a safe, open-source application. The "damaged" warning is a standard macOS security measure for unsigned apps. You can verify the source code in this repository. I'm working on getting the app properly code-signed to eliminate this step in future releases.

### Build from Source

1. **Clone the repository:**
```bash
git clone https://github.com/AlbertoBarrago/RSS-Reader.git
cd RSS-Reader
```

2. **Open in Xcode:**
```bash
open RSSReader.xcodeproj
```

3. **Configure target:**
   - Select "My Mac" from the destination menu in Xcode
   - Ensure you're targeting macOS (not iOS simulator)

4. **Build and run:**
   - Press `Cmd + R` or click the Run button
   - For command-line builds, see [RUN.md](RUN.md)

### Usage

- Launch the app - it will appear in your menu bar
- Click the RSS Reader icon in the menu bar
- Add your favorite RSS feeds using the "+" button
- Browse articles and click to read in your default browser
- Use the refresh button to manually update feeds

### Contributing
Contributions are welcome! Please feel free to:

- 🐛 Report bugs by opening an issue
- 💡 Suggest new features
- 🔧 Submit pull requests

### Development Setup

- Fork the repository
- Create a feature branch (git checkout -b feature/amazing-feature)
- Commit your changes (git commit -m 'Add amazing feature')
- Push to the branch (git push origin feature/amazing-feature)
- Open a Pull Request

### Useful Links
[SUGGESTED RSS](SUGGESTED.md)

### License
This project is licensed under the MIT License - see the LICENSE file for details.

⭐ If you find this project useful, please consider giving it a star!
