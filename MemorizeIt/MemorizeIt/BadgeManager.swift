//
//  BadgeManager.swift
//  MemorizeIt
//
//  Tracks earned achievement badges. Persisted in UserDefaults so we don't need
//  a SwiftData schema migration. Designed to be called from
//  MemorizeView.savePracticeSession after stats have been updated.
//

import Foundation
import SwiftUI

enum Badge: String, CaseIterable, Identifiable {
    case firstSession
    case firstPerfect
    case sevenDayStreak
    case thirtyDayStreak
    case tenVerses
    case fiftySessions
    case hundredSessions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSession: return "First Steps"
        case .firstPerfect: return "Flawless"
        case .sevenDayStreak: return "Week Strong"
        case .thirtyDayStreak: return "Month Master"
        case .tenVerses: return "Library Builder"
        case .fiftySessions: return "Dedicated"
        case .hundredSessions: return "Centurion"
        }
    }

    var description: String {
        switch self {
        case .firstSession: return "Completed your first practice session"
        case .firstPerfect: return "Reached 100% accuracy in a session"
        case .sevenDayStreak: return "Practiced 7 days in a row"
        case .thirtyDayStreak: return "Practiced 30 days in a row"
        case .tenVerses: return "Added 10 verses to your library"
        case .fiftySessions: return "Completed 50 practice sessions"
        case .hundredSessions: return "Completed 100 practice sessions"
        }
    }

    var icon: String {
        switch self {
        case .firstSession: return "figure.walk"
        case .firstPerfect: return "checkmark.seal.fill"
        case .sevenDayStreak: return "flame.fill"
        case .thirtyDayStreak: return "crown.fill"
        case .tenVerses: return "books.vertical.fill"
        case .fiftySessions: return "rosette"
        case .hundredSessions: return "trophy.fill"
        }
    }

    var color: Color {
        switch self {
        case .firstSession: return .blue
        case .firstPerfect: return .green
        case .sevenDayStreak: return .orange
        case .thirtyDayStreak: return .purple
        case .tenVerses: return .indigo
        case .fiftySessions: return .pink
        case .hundredSessions: return .yellow
        }
    }
}

@MainActor
final class BadgeManager: ObservableObject {
    static let shared = BadgeManager()

    private let storageKey = "earnedBadges"

    @Published private(set) var earned: Set<Badge> = []

    private init() {
        if let raw = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            earned = Set(raw.compactMap(Badge.init(rawValue:)))
        }
    }

    func isEarned(_ badge: Badge) -> Bool { earned.contains(badge) }

    /// Evaluate all badge rules against current state. Returns the badges
    /// newly awarded by this call (caller can display a celebration).
    @discardableResult
    func evaluate(
        currentStreak: Int,
        totalSessions: Int,
        verseCount: Int,
        latestAccuracy: Double
    ) -> [Badge] {
        var newlyEarned: [Badge] = []

        func award(_ badge: Badge, when condition: Bool) {
            guard condition, !earned.contains(badge) else { return }
            earned.insert(badge)
            newlyEarned.append(badge)
        }

        award(.firstSession, when: totalSessions >= 1)
        award(.firstPerfect, when: latestAccuracy >= 100.0)
        award(.sevenDayStreak, when: currentStreak >= 7)
        award(.thirtyDayStreak, when: currentStreak >= 30)
        award(.tenVerses, when: verseCount >= 10)
        award(.fiftySessions, when: totalSessions >= 50)
        award(.hundredSessions, when: totalSessions >= 100)

        if !newlyEarned.isEmpty {
            persist()
        }
        return newlyEarned
    }

    private func persist() {
        UserDefaults.standard.set(earned.map(\.rawValue), forKey: storageKey)
    }

    #if DEBUG
    func reset() {
        earned = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
    #endif
}

// MARK: - Badge UI

struct BadgeView: View {
    let badge: Badge
    let isEarned: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isEarned ? badge.color.opacity(0.18) : Color.gray.opacity(0.12))
                    .frame(width: 56, height: 56)

                Image(systemName: isEarned ? badge.icon : "lock.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isEarned ? badge.color : .secondary.opacity(0.6))
            }

            Text(badge.title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(isEarned ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(width: 80)
        .opacity(isEarned ? 1 : 0.6)
    }
}

struct BadgeStripView: View {
    @StateObject private var manager = BadgeManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Achievements")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Text("\(manager.earned.count)/\(Badge.allCases.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Badge.allCases) { badge in
                        BadgeView(badge: badge, isEarned: manager.isEarned(badge))
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Weekly Goal

/// Tracks how many practice sessions the user has completed in the current
/// ISO week. Resets automatically when the week changes. Backed by
/// UserDefaults so we avoid a SwiftData schema migration.
@MainActor
final class WeeklyGoalStore: ObservableObject {
    static let shared = WeeklyGoalStore()

    private let goalKey = "weeklyGoalTarget"
    private let countKey = "weeklyGoalCount"
    private let weekKey = "weeklyGoalWeekStamp"

    /// Target number of sessions per week. User-configurable in Settings.
    @Published var target: Int {
        didSet { UserDefaults.standard.set(target, forKey: goalKey) }
    }

    @Published private(set) var completed: Int = 0

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(completed) / Double(target), 1.0)
    }

    var isComplete: Bool { completed >= target }

    private init() {
        let storedTarget = UserDefaults.standard.integer(forKey: goalKey)
        target = storedTarget > 0 ? storedTarget : 5
        refreshIfWeekChanged()
        completed = UserDefaults.standard.integer(forKey: countKey)
    }

    /// Call after each completed practice session.
    func recordSession() {
        refreshIfWeekChanged()
        completed += 1
        UserDefaults.standard.set(completed, forKey: countKey)
    }

    /// Resets the count if we've crossed into a new ISO week.
    private func refreshIfWeekChanged() {
        let stamp = Self.currentWeekStamp()
        let stored = UserDefaults.standard.string(forKey: weekKey)
        if stored != stamp {
            UserDefaults.standard.set(stamp, forKey: weekKey)
            UserDefaults.standard.set(0, forKey: countKey)
            completed = 0
        }
    }

    private static func currentWeekStamp() -> String {
        let cal = Calendar(identifier: .iso8601)
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(comps.yearForWeekOfYear ?? 0)-W\(comps.weekOfYear ?? 0)"
    }

    #if DEBUG
    func reset() {
        completed = 0
        UserDefaults.standard.removeObject(forKey: countKey)
        UserDefaults.standard.removeObject(forKey: weekKey)
    }
    #endif
}

/// Weekly progress ring + label for HomeView.
struct WeeklyGoalCard: View {
    @StateObject private var store = WeeklyGoalStore.shared

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 56, height: 56)

                Circle()
                    .trim(from: 0, to: store.progress)
                    .stroke(
                        LinearGradient(
                            colors: [Theme.primary, Theme.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: store.progress)

                if store.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.primary)
                } else {
                    Text("\(store.completed)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.primary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly Goal")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(store.isComplete
                     ? "Goal hit — nice work!"
                     : "\(store.completed) of \(store.target) sessions this week")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Celebration overlay shown briefly when a new badge is earned.
struct BadgeEarnedToast: View {
    let badge: Badge
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(badge.color.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: badge.icon)
                    .font(.system(size: 36))
                    .foregroundColor(badge.color)
            }

            Text("Badge Earned!")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text(badge.title)
                .font(.title3)
                .fontWeight(.bold)

            Text(badge.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 6)
        .padding(.horizontal, 48)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1
                opacity = 1
            }
        }
    }
}
