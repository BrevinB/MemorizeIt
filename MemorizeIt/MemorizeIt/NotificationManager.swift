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
    func scheduleDailyReminder(at time: Date, dueCount: Int = 0) async {
        // First, remove any existing daily reminder
        cancelDailyReminder()

        // Check authorization
        guard isAuthorized else {
            print("Notifications not authorized")
            return
        }

        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Time to Practice!"

        if dueCount > 0 {
            content.body = "You have \(dueCount) verse\(dueCount == 1 ? "" : "s") due for review. Keep your streak going!"
        } else {
            content.body = "Take a few minutes to practice your verses and strengthen your memory."
        }

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
        "Don't break your streak! A few minutes of practice makes a difference.",
        "Your future self will thank you for practicing today.",
        "Small daily efforts lead to big results. Let's go!",
        "Ready to strengthen your memory? Your verses await!"
    ]

    /// Get a random motivational message
    static func randomMotivationalMessage() -> String {
        motivationalMessages.randomElement() ?? motivationalMessages[0]
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
