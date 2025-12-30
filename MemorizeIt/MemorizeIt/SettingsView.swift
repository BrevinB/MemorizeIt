//
//  SettingsView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [MemorizeItemModel]
    @Query private var appStats: [AppStats]

    @StateObject private var bibleAPI = BibleAPIService()
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("dailyReminderTime") private var dailyReminderTime = Date()
    @AppStorage("defaultDifficulty") private var defaultDifficulty = "fullText"
    @AppStorage("showVerseNumbers") private var showVerseNumbers = false

    @State private var showDeleteConfirmation = false
    @State private var showResetStatsConfirmation = false
    @State private var showPermissionDeniedAlert = false
    @State private var showPaywall = false

    private var dueForReviewCount: Int {
        allItems.filter { $0.isDueForReview }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // Subscription Section
                Section {
                    if purchaseManager.isPremium {
                        // Premium user - show status
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Premium Active")
                                    .fontWeight(.medium)

                                if let expiration = purchaseManager.expirationDate {
                                    Text(purchaseManager.willRenew ? "Renews \(expiration.formatted(date: .abbreviated, time: .omitted))" : "Expires \(expiration.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            if let url = purchaseManager.managementURL {
                                Link(destination: url) {
                                    Text("Manage")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.primary)
                                }
                            }
                        }
                    } else {
                        // Free user - show upgrade prompt
                        Button {
                            showPaywall = true
                        } label: {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Upgrade to Premium")
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)

                                    Text("\(purchaseManager.versesRemaining(currentCount: allItems.count)) verses remaining")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Subscription")
                } footer: {
                    if !purchaseManager.isPremium {
                        Text("Unlock unlimited verses, all difficulty modes, and more.")
                    }
                }

                // Bible Settings Section
                Section {
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .foregroundColor(Theme.primary)
                            .frame(width: 30)

                        Text("Default Translation")

                        Spacer()

                        Menu {
                            Picker("Translation", selection: $bibleAPI.selectedTranslation) {
                                ForEach(BibleTranslation.available) { translation in
                                    VStack(alignment: .leading) {
                                        Text(translation.abbreviation)
                                            .font(.headline)
                                        Text(translation.name)
                                            .font(.caption)
                                    }
                                    .tag(translation)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(bibleAPI.selectedTranslation.abbreviation)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Toggle(isOn: $showVerseNumbers) {
                        HStack {
                            Image(systemName: "number")
                                .foregroundColor(Theme.primary)
                                .frame(width: 30)
                            Text("Show Verse Numbers")
                        }
                    }
                } header: {
                    Text("Bible Settings")
                }

                // Practice Settings Section
                Section {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(Theme.primary)
                            .frame(width: 30)

                        Text("Default Difficulty")

                        Spacer()

                        Menu {
                            Picker("Difficulty", selection: $defaultDifficulty) {
                                Text("Full Text").tag("fullText")
                                Text("Hidden Words").tag("hiddenWords")
                                Text("Blank Canvas").tag("blankCanvas")
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(difficultyDisplayName(defaultDifficulty))
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Practice Settings")
                }

                // Notifications Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundColor(Theme.primary)
                                .frame(width: 30)
                            Text("Daily Reminders")
                        }
                    }
                    .onChange(of: notificationsEnabled) { oldValue, newValue in
                        handleNotificationToggle(enabled: newValue)
                    }

                    if notificationsEnabled {
                        DatePicker(
                            selection: $dailyReminderTime,
                            displayedComponents: .hourAndMinute
                        ) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(Theme.primary)
                                    .frame(width: 30)
                                Text("Reminder Time")
                            }
                        }
                        .onChange(of: dailyReminderTime) { oldValue, newValue in
                            scheduleNotification()
                        }
                    }

                    // Show permission status if denied
                    if notificationManager.authorizationStatus == .denied {
                        Button {
                            openAppSettings()
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notifications Disabled")
                                        .foregroundColor(.primary)
                                    Text("Tap to open Settings")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    if notificationsEnabled {
                        Text("You'll receive a daily reminder at \(formattedReminderTime) to practice your verses.")
                    } else if notificationManager.authorizationStatus == .denied {
                        Text("Enable notifications in Settings to receive daily reminders.")
                    }
                }

                // Data Management Section
                Section {
                    Button(role: .destructive) {
                        showResetStatsConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "chart.line.downtrend.xyaxis")
                                .frame(width: 30)
                            Text("Reset Statistics")
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .frame(width: 30)
                            Text("Delete All Verses")
                        }
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("These actions cannot be undone.")
                }

                // About Section
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(Theme.primary)
                            .frame(width: 30)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "book.pages.fill")
                            .foregroundColor(Theme.primary)
                            .frame(width: 30)
                        Text("Total Verses")
                        Spacer()
                        Text("\(allItems.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(Theme.primary)
                            .frame(width: 30)
                        Text("Total Practice Time")
                        Spacer()
                        Text(formatTime(totalPracticeTime))
                            .foregroundColor(.secondary)
                    }

                    Button {
                        ReviewManager.shared.requestReviewManually()
                    } label: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 30)
                            Text("Rate MemorizeIt")
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }

                #if DEBUG
                // Debug Section - only visible in development builds
                Section {
                    Toggle(isOn: $purchaseManager.debugOverridePremium) {
                        HStack {
                            Image(systemName: "hammer.fill")
                                .foregroundColor(.purple)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Simulate Premium")
                                Text("Bypass subscription check")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onChange(of: purchaseManager.debugOverridePremium) { _, newValue in
                        purchaseManager.isSubscribed = newValue || purchaseManager.customerInfo?.entitlements[PurchaseManager.premiumEntitlement]?.isActive == true
                    }

                    Button {
                        loadScreenshotData()
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Load Screenshot Data")
                                Text("Add sample verses with progress")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button(role: .destructive) {
                        clearAllDebugData()
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .frame(width: 30)
                            Text("Clear All Data")
                        }
                    }

                    Divider()

                    Button {
                        ReviewManager.shared.forceShowReview()
                    } label: {
                        HStack {
                            Image(systemName: "star.bubble")
                                .foregroundColor(.yellow)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Force Show Review Prompt")
                                Text("Test the review dialog")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Button {
                        ReviewManager.shared.resetTracking()
                        HapticManager.shared.notification(type: .success)
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .foregroundColor(.orange)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reset Review Tracking")
                                Text("Clear review request history")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("Debug Options", systemImage: "ladybug.fill")
                } footer: {
                    Text("These options are only available in development builds and will not appear in the App Store version.")
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.primary)
                }
            }
            .confirmationDialog(
                "Delete All Verses",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) {
                    deleteAllVerses()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all \(allItems.count) verses and their practice history. This action cannot be undone.")
            }
            .confirmationDialog(
                "Reset Statistics",
                isPresented: $showResetStatsConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    resetStatistics()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset your streak, practice sessions, and all progress tracking. Your saved verses will remain.")
            }
            .alert("Notifications Disabled", isPresented: $showPermissionDeniedAlert) {
                Button("Open Settings") {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("To receive daily reminders, please enable notifications in your device Settings.")
            }
            .onAppear {
                Task {
                    await notificationManager.checkAuthorizationStatus()
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Notification Helpers

    private var formattedReminderTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: dailyReminderTime)
    }

    private func handleNotificationToggle(enabled: Bool) {
        if enabled {
            Task {
                // Request permission if not already authorized
                if !notificationManager.isAuthorized {
                    let granted = await notificationManager.requestAuthorization()
                    if !granted {
                        // Permission denied - disable toggle and show alert
                        await MainActor.run {
                            notificationsEnabled = false
                            if notificationManager.authorizationStatus == .denied {
                                showPermissionDeniedAlert = true
                            }
                        }
                        return
                    }
                }
                // Schedule the notification
                scheduleNotification()
            }
        } else {
            // Cancel notifications
            notificationManager.cancelDailyReminder()
            Task {
                await notificationManager.clearBadge()
            }
        }
        HapticManager.shared.impact(style: .light)
    }

    private func scheduleNotification() {
        Task {
            await notificationManager.scheduleDailyReminder(
                at: dailyReminderTime,
                dueCount: dueForReviewCount
            )
        }
    }

    private func openAppSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }

    private var totalPracticeTime: TimeInterval {
        allItems.reduce(0) { total, item in
            total + item.practiceSessions.reduce(0) { $0 + $1.timeSpent }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func difficultyDisplayName(_ difficulty: String) -> String {
        switch difficulty {
        case "fullText": return "Full Text"
        case "hiddenWords": return "Hidden Words"
        case "blankCanvas": return "Blank Canvas"
        default: return "Full Text"
        }
    }

    private func deleteAllVerses() {
        for item in allItems {
            modelContext.delete(item)
        }

        do {
            try modelContext.save()
            HapticManager.shared.notification(type: .success)
        } catch {
            print("Error deleting verses: \(error)")
            HapticManager.shared.notification(type: .error)
        }
    }

    private func resetStatistics() {
        // Reset app stats
        for stats in appStats {
            stats.currentStreak = 0
            stats.longestStreak = 0
            stats.totalPracticeSessions = 0
            stats.totalTimeSpent = 0
            stats.lastPracticeDate = nil
        }

        // Reset all item progress by deleting practice sessions
        for item in allItems {
            item.lastPracticedAt = nil

            // Delete all practice sessions (this will also update practiceCount since it's computed)
            for session in item.practiceSessions {
                modelContext.delete(session)
            }
        }

        do {
            try modelContext.save()
            HapticManager.shared.notification(type: .success)
        } catch {
            print("Error resetting statistics: \(error)")
            HapticManager.shared.notification(type: .error)
        }
    }

    // MARK: - Debug Data Functions
    #if DEBUG
    private func loadScreenshotData() {
        // Clear existing data first
        clearAllDebugData()

        let calendar = Calendar.current

        // MARK: - Bible Verses (various progress levels)
        let bibleVerses: [(title: String, text: String, translation: String, daysAgo: Int, sessions: [(accuracy: Double, daysAgo: Int)], isFavorite: Bool)] = [
            // Mastered verses (90%+ progress)
            (
                "John 3:16",
                "For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.",
                "NIV",
                30,
                [(95, 28), (92, 21), (98, 14), (96, 7), (99, 2), (100, 0)],
                true
            ),
            (
                "Philippians 4:13",
                "I can do all things through Christ who strengthens me.",
                "NKJV",
                25,
                [(88, 22), (94, 15), (96, 8), (98, 3), (100, 1)],
                true
            ),
            (
                "Jeremiah 29:11",
                "For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.",
                "NIV",
                20,
                [(85, 18), (90, 12), (95, 6), (97, 2)],
                false
            ),
            // In progress verses (40-89% progress)
            (
                "Romans 8:28",
                "And we know that in all things God works for the good of those who love him, who have been called according to his purpose.",
                "NIV",
                14,
                [(72, 12), (78, 8), (85, 4)],
                true
            ),
            (
                "Proverbs 3:5-6",
                "Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.",
                "NIV",
                10,
                [(65, 8), (75, 4)],
                false
            ),
            (
                "Isaiah 41:10",
                "So do not fear, for I am with you; do not be dismayed, for I am your God. I will strengthen you and help you; I will uphold you with my righteous right hand.",
                "NIV",
                7,
                [(70, 5), (82, 2)],
                false
            ),
            (
                "Psalm 23:1-3",
                "The Lord is my shepherd, I lack nothing. He makes me lie down in green pastures, he leads me beside quiet waters, he refreshes my soul.",
                "NIV",
                5,
                [(68, 3)],
                false
            ),
            // New verses (no practice yet)
            (
                "Matthew 28:19-20",
                "Therefore go and make disciples of all nations, baptizing them in the name of the Father and of the Son and of the Holy Spirit, and teaching them to obey everything I have commanded you.",
                "NIV",
                2,
                [],
                false
            ),
            (
                "1 Corinthians 13:4-7",
                "Love is patient, love is kind. It does not envy, it does not boast, it is not proud. It does not dishonor others, it is not self-seeking, it is not easily angered, it keeps no record of wrongs.",
                "NIV",
                1,
                [],
                false
            ),
            (
                "Galatians 5:22-23",
                "But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control. Against such things there is no law.",
                "NIV",
                0,
                [],
                true
            )
        ]

        // MARK: - Poems
        let poems: [(title: String, text: String, daysAgo: Int, sessions: [(accuracy: Double, daysAgo: Int)], isFavorite: Bool)] = [
            (
                "The Road Not Taken (excerpt)",
                "Two roads diverged in a wood, and I— I took the one less traveled by, And that has made all the difference.",
                15,
                [(90, 12), (94, 8), (97, 3)],
                true
            ),
            (
                "Invictus (final stanza)",
                "It matters not how strait the gate, How charged with punishments the scroll, I am the master of my fate, I am the captain of my soul.",
                8,
                [(75, 6), (82, 2)],
                false
            ),
            (
                "Hope is the thing with feathers",
                "Hope is the thing with feathers that perches in the soul, and sings the tune without the words, and never stops at all.",
                3,
                [],
                false
            )
        ]

        // MARK: - Speeches
        let speeches: [(title: String, text: String, daysAgo: Int, sessions: [(accuracy: Double, daysAgo: Int)], isFavorite: Bool)] = [
            (
                "I Have a Dream (excerpt)",
                "I have a dream that my four little children will one day live in a nation where they will not be judged by the color of their skin but by the content of their character.",
                12,
                [(85, 10), (92, 5), (96, 1)],
                true
            ),
            (
                "Gettysburg Address (opening)",
                "Four score and seven years ago our fathers brought forth on this continent, a new nation, conceived in Liberty, and dedicated to the proposition that all men are created equal.",
                6,
                [(70, 4)],
                false
            )
        ]

        // Create Bible Verses
        for verse in bibleVerses {
            let createdDate = calendar.date(byAdding: .day, value: -verse.daysAgo, to: Date()) ?? Date()
            let item = MemorizeItemModel(
                title: verse.title,
                categoryName: "Bible Verses",
                memorizeText: verse.text,
                isFavorite: verse.isFavorite,
                createdAt: createdDate,
                translation: verse.translation
            )
            modelContext.insert(item)

            // Add practice sessions
            for session in verse.sessions {
                let sessionDate = calendar.date(byAdding: .day, value: -session.daysAgo, to: Date()) ?? Date()
                let practiceSession = PracticeSession(
                    accuracy: session.accuracy,
                    correctChars: Int(Double(verse.text.count) * session.accuracy / 100),
                    totalChars: verse.text.count,
                    difficultyMode: session.accuracy > 90 ? "blankCanvas" : (session.accuracy > 75 ? "hiddenWords" : "fullText"),
                    timeSpent: Double.random(in: 45...180),
                    date: sessionDate
                )
                practiceSession.item = item
                item.practiceSessions.append(practiceSession)
                item.lastPracticedAt = sessionDate

                // Update spaced repetition
                item.updateSpacedRepetition(accuracy: session.accuracy)
            }
        }

        // Create Poems
        for poem in poems {
            let createdDate = calendar.date(byAdding: .day, value: -poem.daysAgo, to: Date()) ?? Date()
            let item = MemorizeItemModel(
                title: poem.title,
                categoryName: "Poems",
                memorizeText: poem.text,
                isFavorite: poem.isFavorite,
                createdAt: createdDate
            )
            modelContext.insert(item)

            for session in poem.sessions {
                let sessionDate = calendar.date(byAdding: .day, value: -session.daysAgo, to: Date()) ?? Date()
                let practiceSession = PracticeSession(
                    accuracy: session.accuracy,
                    correctChars: Int(Double(poem.text.count) * session.accuracy / 100),
                    totalChars: poem.text.count,
                    difficultyMode: "fullText",
                    timeSpent: Double.random(in: 30...120),
                    date: sessionDate
                )
                practiceSession.item = item
                item.practiceSessions.append(practiceSession)
                item.lastPracticedAt = sessionDate
                item.updateSpacedRepetition(accuracy: session.accuracy)
            }
        }

        // Create Speeches
        for speech in speeches {
            let createdDate = calendar.date(byAdding: .day, value: -speech.daysAgo, to: Date()) ?? Date()
            let item = MemorizeItemModel(
                title: speech.title,
                categoryName: "Speeches",
                memorizeText: speech.text,
                isFavorite: speech.isFavorite,
                createdAt: createdDate
            )
            modelContext.insert(item)

            for session in speech.sessions {
                let sessionDate = calendar.date(byAdding: .day, value: -session.daysAgo, to: Date()) ?? Date()
                let practiceSession = PracticeSession(
                    accuracy: session.accuracy,
                    correctChars: Int(Double(speech.text.count) * session.accuracy / 100),
                    totalChars: speech.text.count,
                    difficultyMode: "fullText",
                    timeSpent: Double.random(in: 60...180),
                    date: sessionDate
                )
                practiceSession.item = item
                item.practiceSessions.append(practiceSession)
                item.lastPracticedAt = sessionDate
                item.updateSpacedRepetition(accuracy: session.accuracy)
            }
        }

        // Create/Update AppStats with impressive numbers
        let stats: AppStats
        if let existingStats = appStats.first {
            stats = existingStats
        } else {
            stats = AppStats()
            modelContext.insert(stats)
        }

        stats.currentStreak = 12
        stats.longestStreak = 28
        stats.totalPracticeSessions = 47
        stats.totalTimeSpent = 3600 * 2.5 // 2.5 hours
        stats.lastPracticeDate = Date()

        do {
            try modelContext.save()
            HapticManager.shared.notification(type: .success)
        } catch {
            print("Error loading screenshot data: \(error)")
            HapticManager.shared.notification(type: .error)
        }
    }

    private func clearAllDebugData() {
        // Delete all items
        for item in allItems {
            modelContext.delete(item)
        }

        // Reset stats
        for stats in appStats {
            stats.currentStreak = 0
            stats.longestStreak = 0
            stats.totalPracticeSessions = 0
            stats.totalTimeSpent = 0
            stats.lastPracticeDate = nil
        }

        do {
            try modelContext.save()
        } catch {
            print("Error clearing debug data: \(error)")
        }
    }
    #endif
}

#Preview {
    SettingsView()
}
