//
//  HomeView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock on 10/2/24.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    /// Called when the user taps a quick-stat card; the tab bar uses this to
    /// switch to the Stats tab instead of pushing a nested screen.
    var openStats: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemorizeItemModel.createdAt, order: .reverse) private var allItems: [MemorizeItemModel]
    @Query private var appStats: [AppStats]

    @State private var showAddNewMemorizeItem: Bool = false
    @State private var navigationPath = NavigationPath()
    @State private var itemToNavigate: MemorizeItemModel?

    /// Newly added items that haven't been practiced yet, newest first
    var newlyAddedItems: [MemorizeItemModel] {
        allItems.filter { $0.practiceCount == 0 }
    }

    var recentItems: [MemorizeItemModel] {
        allItems.filter { $0.lastPracticedAt != nil }
            .sorted { ($0.lastPracticedAt ?? Date.distantPast) > ($1.lastPracticedAt ?? Date.distantPast) }
            .prefix(5)
            .map { $0 }
    }

    /// Items due for review based on spaced repetition algorithm (excludes never-practiced items)
    var dueForReviewItems: [MemorizeItemModel] {
        allItems.filter { $0.isDueForPractice }
            .sorted { item1, item2 in
                // Sort by most overdue first, then by last practiced
                let days1 = item1.daysUntilReview
                let days2 = item2.daysUntilReview
                if days1 != days2 {
                    return days1 < days2 // More overdue first
                }
                return (item1.lastPracticedAt ?? Date.distantPast) < (item2.lastPracticedAt ?? Date.distantPast)
            }
    }

    var stats: AppStats {
        if let existingStats = appStats.first {
            return existingStats
        } else {
            let newStats = AppStats()
            modelContext.insert(newStats)
            return newStats
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Quick Stats
                    HStack(spacing: 16) {
                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            openStats?()
                        }) {
                            QuickStatCard(
                                value: "\(stats.currentStreak)",
                                label: "Day Streak",
                                icon: "flame.fill",
                                iconColor: .orange
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())

                        Button(action: {
                            HapticManager.shared.impact(style: .light)
                            openStats?()
                        }) {
                            QuickStatCard(
                                value: "\(allItems.count)",
                                label: "Verses",
                                icon: "book.closed.fill",
                                iconColor: Theme.primary
                            )
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .cardAppear(delay: 0.1)

                    // Weekly Goal
                    WeeklyGoalCard()
                        .padding(.horizontal)
                        .cardAppear(delay: 0.12)

                    // Due for Review Section
                    if !allItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: dueForReviewItems.isEmpty ? "checkmark.seal.fill" : "bell.badge.fill")
                                    .foregroundColor(dueForReviewItems.isEmpty ? .green : .orange)
                                Text(dueForReviewItems.isEmpty ? "All Caught Up!" : "Due for Review")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Spacer()

                                if !dueForReviewItems.isEmpty {
                                    Text("\(dueForReviewItems.count)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.orange)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)

                            // "Practice Now" CTA - batches the top due verses into a back-to-back session
                            if !dueForReviewItems.isEmpty {
                                NavigationLink {
                                    PracticeQueueView(items: Array(dueForReviewItems.prefix(5)))
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "play.fill")
                                            .font(.subheadline)
                                        Text("Practice Now")
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Text("\(min(dueForReviewItems.count, 5)) verses • ~5 min")
                                            .font(.caption)
                                            .opacity(0.85)
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: [Theme.primary, Theme.primaryDark],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(14)
                                }
                                .buttonStyle(ScaleButtonStyle())
                                .padding(.horizontal)
                            }

                            if dueForReviewItems.isEmpty {
                                // All caught up state
                                HStack(spacing: 16) {
                                    Image(systemName: "star.fill")
                                        .font(.title)
                                        .foregroundColor(.yellow)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Great job!")
                                            .font(.headline)
                                        Text("No verses due for review. Keep up the good work!")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .cardAppear(delay: 0.15)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(Array(dueForReviewItems.prefix(5).enumerated()), id: \.element.id) { index, item in
                                            NavigationLink(destination: MemorizeView(item: item)) {
                                                DueReviewCard(item: item)
                                            }
                                            .buttonStyle(ScaleButtonStyle())
                                            .cardAppear(delay: 0.15 + Double(index) * 0.05)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    // Newly Added Section - items never practiced, newest first
                    if !newlyAddedItems.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.orange)
                                Text("Newly Added")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Spacer()

                                Text("\(newlyAddedItems.count)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)

                            VStack(spacing: 12) {
                                ForEach(Array(newlyAddedItems.prefix(5).enumerated()), id: \.element.id) { index, item in
                                    NavigationLink(destination: MemorizeView(item: item)) {
                                        MemorizeItemModelRow(item: item)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .cardAppear(delay: 0.2 + Double(index) * 0.1)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Show overall empty state if no verses at all
                    if allItems.isEmpty {
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary.opacity(0.1))
                                    .frame(width: 120, height: 120)

                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(Theme.primary.opacity(0.8))
                            }

                            VStack(spacing: 8) {
                                Text("Start Your Journey")
                                    .font(.title2)
                                    .fontWeight(.bold)

                                Text("Add your first verse to begin memorizing")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }

                            Button(action: {
                                HapticManager.shared.impact(style: .light)
                                showAddNewMemorizeItem = true
                            }) {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add Your First Verse")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Theme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .buttonStyle(BounceButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .cardAppear(delay: 0.3)
                    } else {
                        // Recent Section - only show if there are recent items
                        if !recentItems.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "clock.fill")
                                        .foregroundColor(.blue)
                                    Text("Recent")
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                .padding(.horizontal)

                                VStack(spacing: 12) {
                                    ForEach(Array(recentItems.enumerated()), id: \.element.id) { index, item in
                                        NavigationLink(destination: MemorizeView(item: item)) {
                                            RecentItemRow(title: item.title, category: item.categoryName)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .cardAppear(delay: 0.5 + Double(index) * 0.1)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Show a compact hint if there are verses but nothing practiced yet
                        if recentItems.isEmpty {
                            VStack(spacing: 12) {
                                Text("💡 Tip")
                                    .font(.headline)

                                Text("Start practicing to see your progress here. Browse everything you've added in the Library tab.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                            .padding(.vertical, 20)
                            .cardAppear(delay: 0.3)
                        }
                    }

                    Spacer(minLength: 20)
                }
            }
            .navigationTitle(greeting)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        showAddNewMemorizeItem.toggle()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Theme.primary)
                    }
                    .buttonStyle(BounceButtonStyle())
                }
            }
            .navigationDestination(for: MemorizeItemModel.self) { item in
                MemorizeView(item: item)
            }
            .sheet(isPresented: $showAddNewMemorizeItem, onDismiss: {
                if let item = itemToNavigate {
                    itemToNavigate = nil
                    navigationPath.append(item)
                }
            }) {
                AddNewItemView(onItemAdded: { newItem in
                    itemToNavigate = newItem
                })
            }
        }
    }
}

// MARK: - Card Components

struct QuickStatCard: View {
    let value: String
    let label: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.primary)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct MemorizeItemModelRow: View {
    let item: MemorizeItemModel

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.categoryColor(for: item.categoryName).opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: Theme.categoryIcon(for: item.categoryName))
                    .font(.system(size: 20))
                    .foregroundColor(Theme.categoryColor(for: item.categoryName))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let translation = item.translation {
                        Text(translation)
                            .font(.caption2)
                            .foregroundColor(Theme.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primary.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                Text(item.memorizeText.prefix(50) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if item.progress > 0 {
                Text("\(Int(item.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.categoryColor(for: item.categoryName))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.categoryColor(for: item.categoryName).opacity(0.15))
                    .cornerRadius(8)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct RecentItemRow: View {
    let title: String
    let category: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.categoryColor(for: category).opacity(0.2))
                    .frame(width: 50, height: 50)

                Image(systemName: Theme.categoryIcon(for: category))
                    .font(.system(size: 20))
                    .foregroundColor(Theme.categoryColor(for: category))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct DueReviewCard: View {
    let item: MemorizeItemModel

    var urgencyColor: Color {
        let days = item.daysUntilReview
        if days < 0 {
            return .red // Overdue
        } else if days == 0 {
            return .orange // Due today
        } else {
            return .green // Upcoming
        }
    }

    var urgencyText: String {
        let days = item.daysUntilReview
        if days < -1 {
            return "\(abs(days)) days overdue"
        } else if days == -1 {
            return "1 day overdue"
        } else if days == 0 {
            return "Due today"
        } else {
            return "Due in \(days) day\(days == 1 ? "" : "s")"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.categoryColor(for: item.categoryName).opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: Theme.categoryIcon(for: item.categoryName))
                        .font(.system(size: 16))
                        .foregroundColor(Theme.categoryColor(for: item.categoryName))
                }

                Spacer()

                // Urgency badge
                Text(urgencyText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(urgencyColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(urgencyColor.opacity(0.15))
                    .cornerRadius(6)
            }

            Text(item.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(2)

            if item.practiceCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text("\(item.practiceCount) practices")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                    Text("New")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
        }
        .padding(12)
        .frame(width: 160)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(urgencyColor.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
}
