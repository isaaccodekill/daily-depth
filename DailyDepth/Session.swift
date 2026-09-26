import Foundation
import SwiftUI
import UserNotifications
import WidgetKit
#if os(iOS)
import ActivityKit
import AppIntents

struct LearningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable { var start: Date; var end: Date; var paused: Bool = false; var remaining: Double = 0 }
    var title: String
}
struct EndLearningSessionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "End learning session"
    static var description = IntentDescription("End your learning timer and dismiss its Live Activity.")
    func perform() async throws -> some IntentResult {
        for activity in Activity<LearningActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
        WidgetBridge.defaults.removeObject(forKey: "sessionRemaining")
        WidgetBridge.defaults.removeObject(forKey: "sessionEnd")
        WidgetBridge.defaults.removeObject(forKey: "sessionStart")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session-complete"])
        return .result()
    }
}
#endif

enum WidgetBridge {
    static let group = "group.com.isaacbello.dailydepth"
    static var defaults: UserDefaults {
        #if os(iOS) && !PERSONAL_PREVIEW
        return UserDefaults(suiteName: group) ?? .standard
        #else
        return .standard
        #endif
    }
    static func update(title: String, count: Int, streak: Int, learnedToday: Bool) {
        defaults.set(title, forKey: "widgetTitle")
        defaults.set(count, forKey: "widgetCount")
        defaults.set(streak, forKey: "widgetStreak")
        defaults.set(learnedToday, forKey: "widgetLearnedToday")
        defaults.set(Date(), forKey: "widgetUpdated")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
#if !WIDGET_EXTENSION
@MainActor final class LearningSession: ObservableObject {
    @Published var start: Date?
    @Published var end: Date?
    @Published var remaining: Double = 0
    var isPaused: Bool { remaining > 0 }
    var pausedTime: String { String(format: "%02d:%02d", Int(ceil(remaining)) / 60, Int(ceil(remaining)) % 60) }
    @Published var title = ""
    @Published var status = ""
    init() { restore() }
    func restore() {
        remaining = WidgetBridge.defaults.double(forKey: "sessionRemaining")
        start = WidgetBridge.defaults.object(forKey: "sessionStart") as? Date
        end = WidgetBridge.defaults.object(forKey: "sessionEnd") as? Date
        title = WidgetBridge.defaults.string(forKey: "sessionTitle") ?? "Learning session"
        if let end, end < Date(), !isPaused { Task { await finish() } }
    }
    func begin(title: String, minutes: Int) async {
        await finish()
        let now = Date(); let finish = now.addingTimeInterval(Double(minutes * 60))
        start = now; end = finish; self.title = title
        WidgetBridge.defaults.set(now, forKey: "sessionStart")
        WidgetBridge.defaults.set(finish, forKey: "sessionEnd")
        WidgetBridge.defaults.set(title, forKey: "sessionTitle")
        status = "Your learning session is running."
        #if os(iOS)
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            do {
                _ = try Activity.request(attributes: LearningActivityAttributes(title: String(title.prefix(120))), content: ActivityContent(state: .init(start: now, end: finish), staleDate: finish), pushType: nil)
                status = "Your session is live on the Lock Screen."
            } catch { status = "Timer started. Live Activity unavailable: \(error.localizedDescription)" }
        } else { status = "Timer started. Enable Live Activities in Daily Depth’s system settings to show it on the Lock Screen." }
        #endif
        await scheduleCompletion(seconds: Double(minutes * 60))
    }
    func togglePause() async {
        guard let end else { return }
        if isPaused {
            let seconds = remaining
            self.end = Date().addingTimeInterval(seconds)
            self.start = Date()
            remaining = 0
            WidgetBridge.defaults.set(self.end, forKey: "sessionEnd")
            WidgetBridge.defaults.set(self.start, forKey: "sessionStart")
            WidgetBridge.defaults.removeObject(forKey: "sessionRemaining")
            await scheduleCompletion(seconds: seconds)
            status = "Back to your idea."
        } else {
            guard end > Date() else { await finish(); return }
            remaining = end.timeIntervalSinceNow
            WidgetBridge.defaults.set(remaining, forKey: "sessionRemaining")
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session-complete"])
            status = "Paused. Pick up whenever you’re ready."
        }
        #if os(iOS)
        if let start, let end = self.end {
            for activity in Activity<LearningActivityAttributes>.activities {
                await activity.update(ActivityContent(state: .init(start: start, end: end, paused: isPaused, remaining: remaining), staleDate: isPaused ? nil : end))
            }
        }
        #endif
    }
    private func scheduleCompletion(seconds: Double) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
            let content = UNMutableNotificationContent(); content.title = "Make the idea yours"; content.body = "Your learning session is complete. Take a moment to save your takeaway."; content.sound = .default; content.categoryIdentifier = "LEARN"
            do { try await center.add(UNNotificationRequest(identifier: "session-complete", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(1, seconds), repeats: false))) }
            catch { status += " The completion notification could not be scheduled." }
        }
    }
    func finish() async {
        #if os(iOS)
        for activity in Activity<LearningActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
        #endif
        start = nil; end = nil; remaining = 0; status = ""
        WidgetBridge.defaults.removeObject(forKey: "sessionRemaining")
        WidgetBridge.defaults.removeObject(forKey: "sessionStart"); WidgetBridge.defaults.removeObject(forKey: "sessionEnd")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["session-complete"])
    }
}
#endif
