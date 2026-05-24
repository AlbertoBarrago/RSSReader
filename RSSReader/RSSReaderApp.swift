//
//  RSSReaderApp.swift
//  RSSReader
//
//  Created by Alberto Barrago on 2025.
//

import AppKit
import SwiftData
import SwiftUI
import ServiceManagement
import UserNotifications

// MARK: - Main App Entry Point
@main
struct RSSReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let modelContainer: ModelContainer
    let modelContext: ModelContext
    
    @StateObject private var viewModel: ContentViewModel

    init() {
           do {
               let container = try ModelContainer(for: RSSFeedItem.self,
                                                  RSSFeedSource.self,
                                                  DeletedArticle.self)
               let context = ModelContext(container)

               self.modelContainer = container
               self.modelContext = context
               _viewModel = StateObject(wrappedValue: ContentViewModel(modelContext: context))
           } catch {
               fatalError("Failed to create ModelContainer: \(error)")
           }
       }

    var body: some Scene {
       
        Window("RSS Reader", id: "desktopView") {
                    ContentView(modelContext: modelContext, style: .rich)
                }
                .defaultPosition(.center)
                .defaultSize(width: 1200, height: 800)
    }
}

// MARK: - AppDelegate for Menubar Integration
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var menubarController: MenubarController!
    @AppStorage("showInMenuBar") private var showInMenuBar = false

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set activation policy before creating menubar controller
        NSApp.setActivationPolicy(showInMenuBar ? .regular : .accessory)

        menubarController = MenubarController()

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted.")
            } else if let error = error {
                print(error.localizedDescription)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender.identifier?.rawValue == "desktopView" {
            sender.orderOut(nil)
            return false
        }
        return true
    }
}


/// MARK: - Menubar Controller
@MainActor
class MenubarController: NSObject, ObservableObject {
    static let shared = MenubarController()
    
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let parser = RSSParser()
    
    private var modelContainer: ModelContainer
    private var modelContext: ModelContext
    @AppStorage("keepOpen") private var keepOpen: Bool = false
    @AppStorage("pollingInterval") private var pollingInterval: TimeInterval = 300
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    
    private var timer: Timer?
    
    override init() {
        do {
            modelContainer = try ModelContainer(for: RSSFeedItem.self, RSSFeedSource.self, DeletedArticle.self)
            modelContext = ModelContext(modelContainer)
        } catch {
            fatalError("Failed to create MenubarController ModelContainer: \(error)")
        }
        
        super.init()

        setupMenubar()
    }
    
    private func setupMenubar() {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = self.statusItem.button {
            button.image = NSImage(systemSymbolName: "antenna.radiowaves.left.and.right", accessibilityDescription: "RSS Reader")
            button.image?.isTemplate = true
            button.action = #selector(handleButtonClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        self.popover = NSPopover()
        self.popover.behavior = .transient
        self.popover.contentSize = NSSize(width: 800, height: 600)
        self.popover.contentViewController = NSHostingController(rootView: ContentView(modelContext: modelContext))

        startTimer()
    }
    


    deinit {
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshFeeds()
            }
        }
    }

    private func refreshFeeds() {
        do {
            let sources = try modelContext.fetch(FetchDescriptor<RSSFeedSource>())
            parser.refreshAllFeeds(sources: sources, in: modelContext) {}
        } catch {
            print("Failed to fetch feed sources: \(error.localizedDescription)")
        }
    }

    @objc private func handleButtonClick() {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                // Right-click: Show the menu
                showRightClickMenu()
            } else if event.type == .leftMouseUp {
                // Left-click: Toggle the popover
                popover.behavior = keepOpen ? .semitransient : .transient
                togglePopover(self)
            }
        }
    }


    private func showRightClickMenu() {
        guard let button = self.statusItem.button else { return }

        let menu = NSMenu()
        
        menu.addItem(NSMenuItem.sectionHeader(title: "Settings"))
        

        let pollingMenuItem = NSMenuItem(title: "Refresh Interval", action: nil, keyEquivalent: "")
        pollingMenuItem.submenu = createPollingIntervalMenu()
        menu.addItem(pollingMenuItem)
        
        let iconTitle = showInMenuBar ? "Hide Desktop Version" : "Show Desktop Version"
          let iconItem = NSMenuItem(title: iconTitle, action: #selector(toggleAppIcon), keyEquivalent: "")
          iconItem.target = self
          menu.addItem(iconItem)

        menu.addItem(NSMenuItem.sectionHeader(title: "About"))

        let aboutItem = NSMenuItem(title: "About RSS Reader", action: #selector(showAboutPanel), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit RSS Reader", action: #selector(NSApplication.shared.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    private func createPollingIntervalMenu() -> NSMenu {
        let menu = NSMenu()
        let intervals: [TimeInterval] = [300, 600, 900, 1800] // 5, 10, 15, 30 minutes

        for interval in intervals {
            let menuItem = NSMenuItem(title: "\(Int(interval / 60)) minutes", action: #selector(changePollingInterval(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = interval
            if pollingInterval == interval {
                menuItem.state = .on
            }
            menu.addItem(menuItem)
        }

        return menu
    }
    
    @objc private func toggleAppIcon() {
        showInMenuBar.toggle()
        NSApp.setActivationPolicy(showInMenuBar ? .regular : .accessory)
    }
    

    @objc private func changePollingInterval(_ sender: NSMenuItem) {
        if let interval = sender.representedObject as? TimeInterval {
            pollingInterval = interval
            startTimer()
        }
    }

    @objc private func toggleKeepOpen() {
        keepOpen.toggle()
    }

    @objc private func toggleDockVisibility() {
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc func showAboutPanel() {
        let creditsString = """
            Developed by: Alberto Barrago
            © 2025-2026 RSS Reader
            """

        let credits = NSAttributedString(
            string: creditsString,
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                .foregroundColor: NSColor.labelColor,
            ]
        )

        NSApplication.shared.orderFrontStandardAboutPanel(
            options: [
                .applicationName: "RSS Reader",
                .credits: credits,
            ]
        )
        
        NSApp.activate(ignoringOtherApps: true)
        
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = self.statusItem.button {
            if self.popover.isShown {
                self.popover.performClose(sender)
            } else {
                let adjustedBounds = NSRect(
                    x: button.bounds.minX,
                    y: button.bounds.minY,
                    width: button.bounds.width,
                    height: button.bounds.height
                )
                self.popover.show(relativeTo: adjustedBounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
