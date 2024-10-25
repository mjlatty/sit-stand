import Foundation
import IOKit.pwr_mgt
import AppKit
import AVFoundation
import WebKit

class IdleTimer {
    private var lastActivity: Date
    private var timer: Timer?
    private var callback: ((Bool) -> Void)?
    private let idleThreshold: TimeInterval = 10 // 1 minute in seconds // TODO switch back to a minute
    private var isCurrentlyIdle = false
    
    // Comprehensive list of video conferencing apps
    private let meetingApps = [
        // Desktop Apps
        "us.zoom.xos",                    // Zoom
        "com.microsoft.teams",            // Microsoft Teams
        "com.microsoft.teams2",           // New Microsoft Teams
        "com.google.meet",                // Google Meet desktop
        "com.cisco.webex.meetings",       // Webex
        "com.cisco.webexmeetings",        // Webex alternative ID
        "com.webex.meetingmanager",       // Webex Meeting Manager
        "com.skype.skype",                // Skype
        "com.bluejeans.BlueJeans",        // BlueJeans
        "com.ringcentral.ringcentralformac", // RingCentral
        "com.ringcentral.RingCentral",    // RingCentral alternative ID
        "com.logmein.gotomeeting",        // GoToMeeting
        "com.discord",                    // Discord
        "slack",                          // Slack
        
        // Browsers (for web-based meetings)
        "com.google.Chrome",              // Chrome
        "com.apple.Safari",               // Safari
        "com.microsoft.edgemac",          // Edge
        "org.mozilla.firefox",            // Firefox
        "com.brave.Browser",              // Brave
        "com.operasoftware.Opera",        // Opera
        "com.vivaldi.Vivaldi"             // Vivaldi
    ]
    
    // Known video streaming domains
    private let videoStreamingDomains = [
        "zoom.us",
        "teams.microsoft.com",
        "meet.google.com",
        "webex.com",
        "netflix.com",
        "youtube.com",
        "vimeo.com",
        "hulu.com",
        "primevideo.amazon.com",
        "disneyplus.com",
        "hbomax.com",
        "peacocktv.com",
        "paramount.com",
        "discoveryplus.com",
        "twitch.tv",
        "dailymotion.com",
        "ted.com",
        "coursera.org",
        "udemy.com",
        "linkedin.com/learning",
        "pluralsight.com",
        "meet.jit.si",
        "whereby.com",
        "8x8.vc",
        "gotomeeting.com",
        "bluejeans.com",
        "slack.com/calls",
        "discord.com/channels"
    ]
    
    init(callback: @escaping (Bool) -> Void) {
        self.lastActivity = Date()
        self.callback = callback
        startMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
    }
    
    private func checkStatus() {
        if !isInMeeting() && !isWatchingVideo() {
            checkIdle()
        }
    }
    
    private func isInMeeting() -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else { return false }
        let bundleIdentifier = activeApp.bundleIdentifier ?? ""
        
        // First check if it's a dedicated meeting app
        if meetingApps.contains(bundleIdentifier) {
            return true
        }
        
        // If it's a browser, check for meeting URLs
        if isBrowser(bundleIdentifier) {
            return isInBrowserMeeting()
        }
        
        return false
    }
    
    private func isBrowser(_ bundleId: String) -> Bool {
        return [
            "com.google.Chrome",
            "com.apple.Safari",
            "com.microsoft.edgemac",
            "org.mozilla.firefox",
            "com.brave.Browser",
            "com.operasoftware.Opera",
            "com.vivaldi.Vivaldi"
        ].contains(bundleId)
    }
    
    private func isInBrowserMeeting() -> Bool {
        // Get active browser tab URL
        if let activeTab = getActiveBrowserTab() {
            return videoStreamingDomains.contains { domain in
                activeTab.lowercased().contains(domain)
            }
        }
        return false
    }
    
    private func getActiveBrowserTab() -> String? {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let bundleId = activeApp.bundleIdentifier ?? ""
        
        // Using Apple Script to get the current URL
        let appleScript: String
        switch bundleId {
        case "com.google.Chrome":
            appleScript = """
            tell application "Google Chrome"
                get URL of active tab of first window
            end tell
            """
        case "com.apple.Safari":
            appleScript = """
            tell application "Safari"
                get URL of current tab of first window
            end tell
            """
        case "com.microsoft.edgemac":
            appleScript = """
            tell application "Microsoft Edge"
                get URL of active tab of first window
            end tell
            """
        case "org.mozilla.firefox":
            appleScript = """
            tell application "Firefox"
                get URL of active tab of first window
            end tell
            """
        default:
            return nil
        }
        
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            if let output = scriptObject.executeAndReturnError(&error).stringValue {
                return output
            }
        }
        return nil
    }
    
    private func isWatchingVideo() -> Bool {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else { return false }
        let bundleIdentifier = activeApp.bundleIdentifier ?? ""
        
        // Check for dedicated video apps
        let videoApps = [
            "com.apple.QuickTimePlayerX",    // QuickTime
            "com.apple.TV",                  // Apple TV
            "com.netflix.Netflix",           // Netflix app
            "com.amazon.PrimeVideo",         // Prime Video app
            "com.disney.disneyplus",         // Disney+ app
            "com.hulu.plus",                 // Hulu app
            "com.google.chrome.app.HBO-NOW", // HBO app
            "com.peacocktv.peacockdesktop",  // Peacock app
            "tv.plex.plex",                  // Plex
            "com.mpv",                       // MPV Player
            "org.videolan.vlc",              // VLC
            "com.colliderli.iina",           // IINA
            "com.apple.Preview"              // Preview
        ]
        
        // If it's a dedicated video app
        if videoApps.contains(bundleIdentifier) {
            return true
        }
        
        // If it's a browser
        if isBrowser(bundleIdentifier) {
            // Check if current tab is a video streaming site
            if let activeTab = getActiveBrowserTab() {
                if videoStreamingDomains.contains(where: { activeTab.lowercased().contains($0) }) {
                    // Also verify audio is playing
                    return !NowPlaying.shared.pausedApps.contains(bundleIdentifier)
                }
            }
        }
        
        return false
    }
    
    private func checkIdle() {
       // Get system idle time using IOKit
       var idleTime: Double = 0
       var iter: io_iterator_t = 0
       
       if IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iter) == KERN_SUCCESS {
           let entry = IOIteratorNext(iter)
           if entry != 0 {
               var dict: Unmanaged<CFMutableDictionary>?
               if IORegistryEntryCreateCFProperties(entry, &dict, kCFAllocatorDefault, 0) == KERN_SUCCESS {
                   if let userActivity = (dict?.takeUnretainedValue() as NSDictionary?)?.value(forKey: "HIDIdleTime") as? NSNumber {
                       idleTime = userActivity.doubleValue / 1_000_000_000 // Convert nanoseconds to seconds
                   }
               }
               IOObjectRelease(entry)
           }
           IOObjectRelease(iter)
       }
       
       let newIdleState = idleTime >= idleThreshold
       
       // Only call callback if state has changed
       if newIdleState != isCurrentlyIdle {
           isCurrentlyIdle = newIdleState
           callback?(newIdleState)
       }
   }
    
    // Helper class to check audio playback status
    class NowPlaying {
        static let shared = NowPlaying()
        private(set) var pausedApps: Set<String> = []
        
        private init() {
            // Start observing audio session notifications
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(handleAudioStatusChange(_:)),
                name: NSWorkspace.didDeactivateApplicationNotification,
                object: nil
            )
        }
        
        @objc private func handleAudioStatusChange(_ notification: Notification) {
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                let bundleId = app.bundleIdentifier ?? ""
                
                // Check if the app is playing audio
                if isAppPlayingAudio(bundleId) {
                    pausedApps.remove(bundleId)
                } else {
                    pausedApps.insert(bundleId)
                }
            }
        }
        
        private func isAppPlayingAudio(_ bundleId: String) -> Bool {
            // For macOS, we'll use NSSound to check audio status
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", "get volume settings"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Check if output contains "output muted:false" and "output volume:0"
                let isMuted = output.contains("output muted:true")
                if let volumeRange = output.range(of: "output volume:"),
                   let volume = Int(output[volumeRange.upperBound...].trimmingCharacters(in: .whitespaces).components(separatedBy: ",")[0]) {
                    return !isMuted && volume > 0
                }
            }
            
            return false
        }
    }
}
