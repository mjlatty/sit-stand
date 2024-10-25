import Foundation
import UserNotifications
import SwiftUI

extension Notification.Name {
    static let standingStateChanged = Notification.Name("standingStateChanged")
    static let timeRemainingChanged = Notification.Name("timeRemainingChanged")
    static let pausedStateChanged = Notification.Name("pausedStateChanged")
}


// Timer Manager to handle timer logic
class TimerManager: ObservableObject {
    @Published var isStanding = false {
            didSet {
                // Notify of state change
                NotificationCenter.default.post(
                    name: .standingStateChanged,
                    object: nil,
                    userInfo: ["isStanding": isStanding]
                )
            }
        }
    @Published var timeRemaining: Int = 30 * 60 {
            didSet {
                NotificationCenter.default.post(
                    name: .timeRemainingChanged,
                    object: nil,
                    userInfo: ["timeRemaining": timeRemaining]
                )
            }
        }
    @Published var isActive = false
    @Published var isPaused = false {
        didSet {
            NotificationCenter.default.post(
                name: .pausedStateChanged,
                object: nil,
                userInfo: ["isPaused": isPaused]
            )
            // Reset idle state when manually unpaused
            if !isPaused {
                isIdle = false
                activityType = .active
            }
        }
    }
    @Published var isIdle = false
    @Published var activityType: ActivityType = .active
    
    enum ActivityType {
        case active
        case idle
        case inMeeting
        case watchingVideo
    }
    
    private var timer: Timer?
    private var idleTimer: IdleTimer?
    
    init() {
        // Post initial states
        NotificationCenter.default.post(
            name: .standingStateChanged,
            object: nil,
            userInfo: ["isStanding": isStanding]
        )
        NotificationCenter.default.post(
            name: .timeRemainingChanged,
            object: nil,
            userInfo: ["timeRemaining": timeRemaining]
        )
        
        // Setup idle timer with enhanced status reporting
        idleTimer = IdleTimer { [weak self] isIdle in
            DispatchQueue.main.async {
                self?.isIdle = isIdle
                if isIdle {
                    self?.activityType = .idle
                    self?.autoPause()
                } else {
                    self?.activityType = .active
                }
            }
        }
    }
    
    func toggleTimer() {
        if isActive {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    func togglePause() {
        isPaused.toggle()
        if isPaused {
            timer?.invalidate()
            timer = nil
        } else {
            startTimer()
        }
    }
        
    private func autoPause() {
        if isActive && !isPaused {
            isPaused = true
            timer?.invalidate()
            timer = nil
        }
    }
    
    func startTimer() {
        isActive = true
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            } else {
                self.switchPosition()
            }
        }
    }
        
    func stopTimer() {
        isActive = false
        isPaused = false
        timer?.invalidate()
        timer = nil
    }
    
    func switchPosition() {
        isStanding.toggle()
        timeRemaining = 30 * 60 // Reset to 30 minutes
        
        // Send notification
        let content = UNMutableNotificationContent()
        content.title = "Time to \(isStanding ? "Stand" : "Sit")!"
        content.body = "Switch your desk position"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// Main Content View
struct ContentView: View {
    @StateObject var timerManager: TimerManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(timerManager.isStanding ? "Standing" : "Sitting")
                .font(.title)
            
            Text(timeString(from: timerManager.timeRemaining))
                .font(.system(size: 40, weight: .bold))
            
            // Activity Status Indicator
            ActivityStatusView(activityType: timerManager.activityType)
            
            HStack(spacing: 20) {
                Button(action: {
                    timerManager.toggleTimer()
                }) {
                    Text(timerManager.isActive ? "Stop" : "Start")
                        .frame(width: 80)
                }
                
                if timerManager.isActive {
                    Button(action: {
                        timerManager.togglePause()
                    }) {
                        Text(timerManager.isPaused ? "Resume" : "Pause")
                            .frame(width: 80)
                    }
                }
            }
        }
        .padding()
    }
    
    func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

struct ActivityStatusView: View {
    let activityType: TimerManager.ActivityType
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(statusColor)
            
            Text(statusText)
                .foregroundColor(statusColor)
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(statusColor.opacity(0.1))
        )
    }
    
    private var iconName: String {
        switch activityType {
        case .active:
            return "person.fill"
        case .idle:
            return "moon.fill"
        case .inMeeting:
            return "video.fill"
        case .watchingVideo:
            return "play.tv.fill"
        }
    }
    
    private var statusText: String {
        switch activityType {
        case .active:
            return "Active"
        case .idle:
            return "System Idle"
        case .inMeeting:
            return "In Meeting"
        case .watchingVideo:
            return "Watching Video"
        }
    }
    
    private var statusColor: Color {
        switch activityType {
        case .active:
            return .green
        case .idle:
            return .orange
        case .inMeeting:
            return .blue
        case .watchingVideo:
            return .purple
        }
    }
}
