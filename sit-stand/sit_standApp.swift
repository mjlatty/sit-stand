import SwiftUI
import UserNotifications

// Main App Structure
@main
struct SitStandTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// App Delegate to handle menu bar setup
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var timer: Timer?
    var eventMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                print("Notification permission granted")
            }
        }
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "⏰"
        
        // Create and configure popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView(timerManager: TimerManager())
        )
        self.popover = popover
        setupEventMonitor()
        
        // Add click action to status bar item
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.target = self
        
        NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleStandingStateChange),
           name: .standingStateChanged,
           object: nil
       )
    }
    
    func updateMenuBarIcon(isStanding: Bool) {
        let icon = isStanding ? "🧍" : "💺"  // Different icon options
        statusItem?.button?.title = icon
    }
    
    @objc func handleStandingStateChange(_ notification: Notification) {
        if let isStanding = notification.userInfo?["isStanding"] as? Bool {
            updateMenuBarIcon(isStanding: isStanding)
        }
    }
    
    func setupEventMonitor() {
            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                if let self = self, let popover = self.popover, popover.isShown {
                    popover.performClose(nil)
                }
            }
        }
    
    func applicationWillTerminate(_ notification: Notification) {
            if let eventMonitor = eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown ?? false {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

