import Foundation
import UserNotifications
import SwiftUI

extension Notification.Name {
    static let standingStateChanged = Notification.Name("standingStateChanged")
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
    @Published var timeRemaining: Int = 30 * 60 // 30 minutes default
    @Published var isActive = false
    private var timer: Timer?
    
    init() {
            // Post initial state when TimerManager is created
            NotificationCenter.default.post(
                name: .standingStateChanged,
                object: nil,
                userInfo: ["isStanding": isStanding]
            )
        }
    
    func toggleTimer() {
        if isActive {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    func startTimer() {
        isActive = true
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
            
            Button(action: {
                timerManager.toggleTimer()
            }) {
                Text(timerManager.isActive ? "Stop" : "Start")
                    .frame(width: 100)
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
