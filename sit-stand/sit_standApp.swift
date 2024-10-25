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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var timer: Timer?
    var eventMonitor: Any?
    var timerManager: TimerManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if granted {
                print("Notification permission granted")
            }
        }
        
        // Create a single instance of TimerManager
        let timerManager = TimerManager()
        self.timerManager = timerManager
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "⏰"
        
        // Create and configure popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: ContentView(timerManager: timerManager)  // Use the same instance
        )
        self.popover = popover
        setupEventMonitor()
        
        // Add click action to status bar item
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.target = self
        
        // Initial update of the menu bar
        updateMenuBarIcon()
        
        // Add observers
        NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleStandingStateChange),
           name: .standingStateChanged,
           object: nil
       )
        
        NotificationCenter.default.addObserver(
           self,
           selector: #selector(handleTimeChange),
           name: .timeRemainingChanged,
           object: nil
       )
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePausedStateChange), name: .pausedStateChanged, object: nil)
    }
    
    @objc func handleStandingStateChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenuBarIcon()
        }
    }
    
    @objc func handleTimeChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenuBarIcon()
        }
    }
    
    @objc func handlePausedStateChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.updateMenuBarIcon()
        }
    }
    
    func updateMenuBarIcon() {
        guard let timerManager = timerManager else { return }
        var icon = ""
        if timerManager.isPaused {
            icon = "⏸"
        } else {
            icon = timerManager.isStanding ? "⬆️" : "⬇️"
        }
        
       
        let timeRemaining = timerManager.timeRemaining
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        let timeString = String(format: "%d:%02d", minutes, seconds)
        
        statusItem?.button?.title = "\(icon) \(timeString)"
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

