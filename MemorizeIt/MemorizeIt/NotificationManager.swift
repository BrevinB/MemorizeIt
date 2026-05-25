//
//  NotificationManager.swift
//  MemorizeIt
//
//  Handles local notifications for daily practice reminders
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let notificationCenter = UNUserNotificationCenter.current()
    private let dailyReminderIdentifier = "daily-practice-reminder"

    private init() {
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// Check current notification authorization status
    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        isAuthorized = settings.authorizationStatus == .authorized
    }

    /// Request notification permissions from the user
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
            await checkAuthorizationStatus()
            return granted
        } catch {
            print("Error requesting notification authorization: \(error)")
            return false
        }
    }

    // MARK: - Daily Reminder Scheduling

    /// Schedule a daily reminder notification at the specified time
    /// - Parameters:
    ///   - time: The time of day to send the reminder
    ///   - dueCount: Number of items due for review (shown in notification)
    ///   - currentStreak: Active day-streak count, used to personalize copy
    func scheduleDailyReminder(at time: Date, dueCount: Int = 0, currentStreak: Int = 0) async {
        // First, remove any existing daily reminder
        cancelDailyReminder()

        // Check authorization
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        let (title, body) = Self.reminderCopy(dueCount: dueCount, currentStreak: currentStreak)
        content.title = title
        content.body = body

        content.sound = .default
        content.badge = dueCount > 0 ? NSNumber(value: dueCount) : nil

        // Extract hour and minute from the time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)

        // Create a daily trigger
        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        // Create the request
        let request = UNNotificationRequest(
            identifier: dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )

        // Schedule the notification
        do {
            try await notificationCenter.add(request)
            print("Daily reminder scheduled for \(components.hour ?? 0):\(String(format: "%02d", components.minute ?? 0))")
        } catch {
            print("Error scheduling daily reminder: \(error)")
        }
    }

    /// Cancel the daily reminder notification
    func cancelDailyReminder() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        print("Daily reminder cancelled")
    }

    /// Update the badge count on the app icon
    func updateBadgeCount(_ count: Int) async {
        do {
            try await notificationCenter.setBadgeCount(count)
        } catch {
            print("Error setting badge count: \(error)")
        }
    }

    /// Clear the badge count
    func clearBadge() async {
        await updateBadgeCount(0)
    }

    // MARK: - Notification Content Variants

    /// Get motivational messages for notifications
    static let motivationalMessages = [
        "Take a few minutes to practice your verses and strengthen your memory.",
        "A little practice each day goes a long way. Let's review!",
        "Your verses are waiting! Keep building that muscle memory.",
        "Consistency is key. Time for a quick practice session!",
        "Your future self will thank you for practicing today.",
        "Small daily efforts lead to big results. Let's go!",
        "Ready to strengthen your memory? Your verses await!"
    ]

    /// Get a random motivational message
    static func randomMotivationalMessage() -> String {
        motivationalMessages.randomElement() ?? motivationalMessages[0]
    }

    /// Build personalized (title, body) reminder copy based on streak and review queue.
    /// Streak-protection copy outperforms generic motivation.
    static func reminderCopy(dueCount: Int, currentStreak: Int) -> (String, String) {
        // 1. Active streak at risk – highest priority, highest conversion.
        if currentStreak >= 2 {
            let title = "Your \(currentStreak)-day streak is at risk 🔥"
            let body: String
            if dueCount > 0 {
                body = "Just \(dueCount) verse\(dueCount == 1 ? "" : "s") to keep your streak alive today."
            } else {
                body = "A 1-minute session today keeps your streak going strong."
            }
            return (title, body)
        }

        // 2. First-day streak – nudge them to come back tomorrow.
        if currentStreak == 1 {
            return ("Start your streak today",
                    "Practice today to begin a 2-day streak. Small wins compound.")
        }

        // 3. No active streak – use queue if available, else motivational fallback.
        if dueCount > 0 {
            return ("Verses ready for review",
                    "You have \(dueCount) verse\(dueCount == 1 ? "" : "s") due. A few minutes is all it takes.")
        }

        return ("Time to Practice", randomMotivationalMessage())
    }
}

// MARK: - Notification Permission View Modifier
struct NotificationPermissionModifier: ViewModifier {
    @StateObject private var notificationManager = NotificationManager.shared
    @Binding var isEnabled: Bool
    let onPermissionDenied: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: isEnabled) { oldValue, newValue in
                if newValue {
                    Task {
                        let granted = await notificationManager.requestAuthorization()
                        if !granted {
                            isEnabled = false
                            onPermissionDenied()
                        }
                    }
                }
            }
    }
}

extension View {
    func notificationPermission(isEnabled: Binding<Bool>, onDenied: @escaping () -> Void) -> some View {
        modifier(NotificationPermissionModifier(isEnabled: isEnabled, onPermissionDenied: onDenied))
    }
}
