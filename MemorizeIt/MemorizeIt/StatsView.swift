//
//  StatsView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var appStats: [AppStats]
    @Query private var allItems: [MemorizeItemModel]
    @Query(sort: \PracticeSession.date, order: .reverse) private var recentSessions: [PracticeSession]
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showPaywall = false

    private var statsGridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)]
        } else {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    private var sessionGridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 350, maximum: 500), spacing: 16)]
        } else {
            return [GridItem(.flexible())]
        }
    }

    var stats: AppStats {
        if let existingStats = appStats.first {
            return existingStats
        } else {
            return AppStats()
        }
    }

    var totalVerses: Int {
        allItems.count
    }

    var averageAccuracy: Double {
        guard !recentSessions.isEmpty else { return 0 }
        let total = recentSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(recentSessions.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak Card
                    VStack(spacing: 16) {
                        Text("\(stats.currentStreak)")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(Theme.primary)

                        Text("Day Streak")
                            .font(.title3)
                            .fontWeight(.medium)

                        if stats.currentStreak > 0 {
                            Text("Keep it up!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        LinearGradient(
                            colors: [Theme.primary.opacity(0.1), Theme.primaryLight.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    .padding(.horizontal)
                    .cardAppear(delay: 0)

                    // Stats Grid - Basic stats for everyone
                    LazyVGrid(columns: statsGridColumns, spacing: 16) {
                        StatCard(
                            icon: "flame.fill",
                            title: "Longest Streak",
                            value: "\(stats.longestStreak)",
                            color: .orange
                        )
                        .cardAppear(delay: 0.1)

                        StatCard(
                            icon: "checkmark.circle.fill",
                            title: "Total Sessions",
                            value: "\(stats.totalPracticeSessions)",
                            color: .green
                        )
                        .cardAppear(delay: 0.2)

                        StatCard(
                            icon: "book.fill",
                            title: "Total Verses",
                            value: "\(totalVerses)",
                            color: Theme.primary
                        )
                        .cardAppear(delay: 0.3)

                        StatCard(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "In Progress",
                            value: "\(allItems.filter { $0.progress > 0 && $0.progress < 1 }.count)",
                            color: .purple
                        )
                        .cardAppear(delay: 0.4)
                    }
                    .padding(.horizontal)

                    // Premium Stats Section
                    if purchaseManager.isPremium {
                        // Premium stats grid
                        LazyVGrid(columns: statsGridColumns, spacing: 16) {
                            StatCard(
                                icon: "clock.fill",
                                title: "Time Spent",
                                value: formatTime(stats.totalTimeSpent),
                                color: .blue
                            )
                            .cardAppear(delay: 0.5)

                            StatCard(
                                icon: "percent",
                                title: "Avg Accuracy",
                                value: String(format: "%.0f%%", averageAccuracy),
                                color: averageAccuracy >= 90 ? .green : averageAccuracy >= 70 ? .orange : .red
                            )
                            .cardAppear(delay: 0.6)
                        }
                        .padding(.horizontal)

                        // Recent Activity
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Recent Activity")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)

                            if recentSessions.isEmpty {
                                EmptyStateView.nothingToShow()
                                    .frame(height: 200)
                            } else {
                                LazyVGrid(columns: sessionGridColumns, spacing: 12) {
                                    ForEach(Array(recentSessions.prefix(10).enumerated()), id: \.element.id) { index, session in
                                        SessionRow(session: session)
                                            .cardAppear(delay: 0.7 + Double(index) * 0.05)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    } else {
                        // Premium upsell for detailed stats
                        VStack(spacing: 16) {
                            HStack {
                                Text("Detailed Statistics")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Spacer()

                                Image(systemName: "lock.fill")
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 12) {
                                LockedStatRow(icon: "clock.fill", title: "Time Spent", color: .blue)
                                LockedStatRow(icon: "percent", title: "Average Accuracy", color: .green)
                                LockedStatRow(icon: "list.bullet.clipboard", title: "Recent Activity", color: .purple)
                                LockedStatRow(icon: "chart.xyaxis.line", title: "Progress Charts", color: .orange)
                            }
                            .padding(.horizontal)

                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Image(systemName: "crown.fill")
                                    Text("Unlock Detailed Stats")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Theme.primary, Theme.primaryDark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                        .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .cardAppear(delay: 0.5)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.top, 20)
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }

            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SessionRow: View {
    let session: PracticeSession

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(accuracyColor.opacity(0.15))
                    .frame(width: 40, height: 40)

                Text(String(format: "%.0f", session.accuracy))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(accuracyColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                if let item = session.item {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                } else {
                    Text("Unknown Item")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text(session.difficultyMode)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(formatDate(session.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.correctChars)/\(session.totalChars)")
                    .font(.caption)
                    .foregroundColor(.primary)

                Text(formatDuration(session.timeSpent))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    var accuracyColor: Color {
        if session.accuracy >= 90 {
            return .green
        } else if session.accuracy >= 70 {
            return .orange
        } else {
            return .red
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

// MARK: - Locked Stat Row for Premium Upsell
struct LockedStatRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    StatsView()
}
