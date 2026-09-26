import Foundation
import UserNotifications
import SwiftUI

@MainActor final class Reminders: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var status = "Choose a time for your daily pause."
    @Published var enabled = UserDefaults.standard.bool(forKey: "reminderEnabled")
    @Published var busy = false
    @Published var openJournal = false
    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let snooze = UNNotificationAction(identifier: "SNOOZE", title: "In 15 minutes", options: [])
        let write = UNNotificationAction(identifier: "WRITE", title: "Write a reflection", options: [.foreground])
        center.setNotificationCategories([UNNotificationCategory(identifier: "LEARN", actions: [write, snooze], intentIdentifiers: [])])
    }
    func refresh() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests()
        enabled = pending.contains { $0.identifier == "daily-learning" } && settings.authorizationStatus != .denied
        UserDefaults.standard.set(enabled, forKey: "reminderEnabled")
        if settings.authorizationStatus == .denied { status = "Notifications are off in system settings. Enable Daily Depth there, then try again." }
        else if enabled { status = "Daily reminder scheduled on this device." }
        else { status = "No reminder scheduled on this device yet." }
    }
    func schedule(at date: Date) async {
        busy = true
        defer { busy = false }
        do {
            let center = UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                status = "Allow notifications in system settings to receive your daily reminder."
                enabled = false
                return
            }
            let content = UNMutableNotificationContent()
            content.title = "A little deeper, every day."
            content.body = "Take 15 minutes to learn one thing about AI. Save the idea—and your own view."
            content.sound = .default
            content.categoryIdentifier = "LEARN"
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            try await center.add(UNNotificationRequest(identifier: "daily-learning", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)))
            enabled = true
            UserDefaults.standard.set(true, forKey: "reminderEnabled")
            status = "Every day at \(date.formatted(date: .omitted, time: .shortened)). You can close the app."
        } catch { status = "Couldn’t schedule: \(error.localizedDescription)" }
    }
    func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-learning", "learning-snooze", "learning-test"])
        enabled = false
        UserDefaults.standard.set(false, forKey: "reminderEnabled")
        status = "Daily reminder paused."
    }
    func test() async {
        do {
            let center = UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { status = "Allow notifications in system settings first."; return }
            let content = UNMutableNotificationContent()
            content.title = "Your daily learning moment"
            content.body = "This is how Daily Depth will remind you. One idea is enough."
            content.sound = .default
            content.categoryIdentifier = "LEARN"
            try await center.add(UNNotificationRequest(identifier: "learning-test", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
            status = "Test notification scheduled in 5 seconds."
        } catch { status = error.localizedDescription }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == "SNOOZE" {
            let content = response.notification.request.content.mutableCopy() as! UNMutableNotificationContent
            center.add(UNNotificationRequest(identifier: "learning-snooze", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 900, repeats: false))) { _ in completionHandler() }
        } else {
            Task { @MainActor in self.openJournal = true; completionHandler() }
        }
    }
}
