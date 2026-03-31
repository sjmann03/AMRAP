import SwiftUI
import ActivityKit
import UserNotifications

@Observable
class TimerManager {
    static let shared = TimerManager()
    
    // Timer State
    var isRunning: Bool = false
    var remainingSeconds: Int = 0
    var totalSeconds: Int = 90
    var timerCompleted: Bool = false
    
    // Settings
    var defaultRestTime: Int = 90
    var vibrateOnComplete: Bool = true
    var soundOnComplete: Bool = true
    var autoStartTimer: Bool = true
    
    // Live Activity
    private var currentActivity: Activity<RestTimerAttributes>? = nil
    
    // Internal timer
    private var timer: Timer? = nil
    private var endTime: Date? = nil
    
    private init() {
        loadSettings()
        requestNotificationPermission()
        
        // Listen for app lifecycle
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        // End any stale activities on launch
        Task {
            await endAllLiveActivities()
        }
    }
    
    // MARK: - Public Methods
    
    func startTimer(seconds: Int? = nil) {
        let duration = seconds ?? defaultRestTime
        totalSeconds = duration
        remainingSeconds = duration
        timerCompleted = false
        isRunning = true
        endTime = Date().addingTimeInterval(TimeInterval(duration))
        
        // Cancel any existing timer
        stopInternalTimer()
        
        // Start new timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.current.add(timer!, forMode: .common)
        
        // Schedule notification
        scheduleNotification(in: duration)
        
        // Start Live Activity
        startLiveActivity()
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    func stopTimer() {
        stopInternalTimer()
        isRunning = false
        remainingSeconds = 0
        timerCompleted = false
        endTime = nil
        
        // Cancel notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["restTimer"])
        
        // End Live Activity immediately
        Task {
            await endAllLiveActivities()
        }
    }
    
    func addTime(_ seconds: Int) {
        guard isRunning else { return }
        remainingSeconds += seconds
        totalSeconds += seconds
        
        if let currentEndTime = endTime {
            endTime = currentEndTime.addingTimeInterval(TimeInterval(seconds))
        }
        
        // Reschedule notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["restTimer"])
        scheduleNotification(in: remainingSeconds)
        
        // Update Live Activity with new endTime
        updateLiveActivity()
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    func skipTimer() {
        stopInternalTimer()
        isRunning = false
        timerCompleted = false  // Don't show "time for next set" when skipping
        remainingSeconds = 0
        endTime = nil
        
        // Cancel notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["restTimer"])
        
        // End Live Activity immediately
        Task {
            await endAllLiveActivities()
        }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // MARK: - Private Methods
    
    private func tick() {
        guard isRunning else { return }
        
        if let endTime = endTime {
            remainingSeconds = max(0, Int(endTime.timeIntervalSinceNow))
        } else {
            remainingSeconds -= 1
        }
        
        if remainingSeconds <= 0 {
            completeTimer()
        }
    }
    
    private func completeTimer() {
        stopInternalTimer()
        isRunning = false
        timerCompleted = true
        remainingSeconds = 0
        endTime = nil
        
        // Haptic feedback
        if vibrateOnComplete {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            }
        }
        
        // End Live Activity
        Task {
            await endAllLiveActivities()
        }
    }
    
    private func stopInternalTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - App Lifecycle
    
    @objc private func appWillEnterForeground() {
        if isRunning, let endTime = endTime {
            remainingSeconds = max(0, Int(endTime.timeIntervalSinceNow))
            
            if remainingSeconds <= 0 {
                completeTimer()
            } else {
                // Restart internal timer
                stopInternalTimer()
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                    self?.tick()
                }
                RunLoop.current.add(timer!, forMode: .common)
            }
        } else if !isRunning {
            // Make sure no stale activities are running
            Task {
                await endAllLiveActivities()
            }
        }
    }
    
    // MARK: - Notifications
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    private func scheduleNotification(in seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Rest Complete! 💪"
        content.body = "Time for your next set"
        content.sound = soundOnComplete ? .default : nil
        content.interruptionLevel = .timeSensitive
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        let request = UNNotificationRequest(identifier: "restTimer", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Live Activity
    
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities not enabled")
            return
        }
        
        // End any existing activities first
        Task {
            await endAllLiveActivities()
            
            // Small delay to ensure cleanup
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            await MainActor.run {
                let attributes = RestTimerAttributes(exerciseName: "Rest Timer")
                let initialState = RestTimerAttributes.ContentState(
                    remainingSeconds: remainingSeconds,
                    totalSeconds: totalSeconds,
                    endTime: endTime ?? Date()
                )
                
                do {
                    let activity = try Activity.request(
                        attributes: attributes,
                        content: .init(state: initialState, staleDate: endTime),
                        pushType: nil
                    )
                    currentActivity = activity
                    print("✅ Started Live Activity: \(activity.id)")
                } catch {
                    print("❌ Failed to start Live Activity: \(error)")
                }
            }
        }
    }
    
    private func updateLiveActivity() {
        guard let activity = currentActivity, isRunning, let endTime = endTime else { return }
        
        let updatedState = RestTimerAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            totalSeconds: totalSeconds,
            endTime: endTime
        )
        
        Task {
            await activity.update(
                ActivityContent(state: updatedState, staleDate: endTime)
            )
        }
    }
    
    private func endAllLiveActivities() async {
        // End our tracked activity
        if let activity = currentActivity {
            let finalState = RestTimerAttributes.ContentState(
                remainingSeconds: 0,
                totalSeconds: totalSeconds,
                endTime: Date()
            )
            
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            
            await MainActor.run {
                currentActivity = nil
            }
            print("✅ Ended tracked Live Activity")
        }
        
        // Also end ANY other activities of this type (cleanup)
        for activity in Activity<RestTimerAttributes>.activities {
            let finalState = RestTimerAttributes.ContentState(
                remainingSeconds: 0,
                totalSeconds: 0,
                endTime: Date()
            )
            
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            print("✅ Ended stale Live Activity: \(activity.id)")
        }
    }
    
    // MARK: - Settings
    
    func loadSettings() {
        defaultRestTime = UserDefaults.standard.integer(forKey: "restTime")
        if defaultRestTime == 0 { defaultRestTime = 90 }
        
        vibrateOnComplete = UserDefaults.standard.object(forKey: "vibrateOnTimer") as? Bool ?? true
        soundOnComplete = UserDefaults.standard.object(forKey: "soundOnTimer") as? Bool ?? true
        autoStartTimer = UserDefaults.standard.object(forKey: "autoStartTimer") as? Bool ?? true
    }
    
    func updateSettings(restTime: Int, vibrate: Bool, sound: Bool, autoStart: Bool) {
        defaultRestTime = restTime
        vibrateOnComplete = vibrate
        soundOnComplete = sound
        autoStartTimer = autoStart
    }
    
    // MARK: - Helpers
    
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
}
