//
//  iPadDashboardView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI
import SwiftData

/// Optimized dashboard view for iPad with adaptive grids
struct iPadDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemorizeItemModel.createdAt, order: .reverse) private var allItems: [MemorizeItemModel]
    @Query private var appStats: [AppStats]

    // Adaptive grid columns for iPad
    private let statsColumns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)
    ]

    private let dueReviewColumns = [
        GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 16)
    ]

    private let recentColumns = [
        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
    ]

    var dueForReviewItems: [MemorizeItemModel] {
        allItems.filter { $0.isDueForReview }
            .sorted { $0.daysUntilReview < $1.daysUntilReview }
    }

    var recentItems: [MemorizeItemModel] {
        allItems.filter { $0.lastPracticedAt != nil }
            .sorted { ($0.lastPracticedAt ?? .distantPast) > ($1.lastPracticedAt ?? .distantPast) }
            .prefix(8)
            .map { $0 }
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

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Stats Grid - Adaptive for iPad
                statsSection

                // Due for Review - Grid layout for iPad
                if !dueForReviewItems.isEmpty {
                    dueForReviewSection
                } else if !allItems.isEmpty {
                    allCaughtUpSection
                }

                // Recent Activity
                if !recentItems.isEmpty {
                    recentSection
                }

                // Empty state
                if allItems.isEmpty {
                    emptyStateSection
                }

                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
    }

    private var statsSection: some View {
        LazyVGrid(columns: statsColumns, spacing: 16) {
            StatCard(
                icon: "flame.fill",
                title: "Day Streak",
                value: "\(stats.currentStreak)",
                color: .orange
            )
            StatCard(
                icon: "book.fill",
                title: "Total Verses",
                value: "\(allItems.count)",
                color: Theme.primary
            )
            StatCard(
                icon: "bell.badge.fill",
                title: "Due Today",
                value: "\(dueForReviewItems.count)",
                color: dueForReviewItems.isEmpty ? .green : .orange
            )
            StatCard(
                icon: "checkmark.circle.fill",
                title: "Sessions",
                value: "\(stats.totalPracticeSessions)",
                color: .green
            )
        }
    }

    private var allCaughtUpSection: some View {
        HStack(spacing: 16) {
            Image(systemName: "star.fill")
                .font(.title)
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 4) {
                Text("All Caught Up!")
                    .font(.headline)
                Text("No verses due for review. Keep up the good work!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
    }

    private var dueForReviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.orange)
                Text("Due for Review")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Text("\(dueForReviewItems.count) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: dueReviewColumns, spacing: 16) {
                ForEach(dueForReviewItems.prefix(12)) { item in
                    NavigationLink(destination: MemorizeView(item: item)) {
                        DueReviewCard(item: item)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.blue)
                Text("Recent Activity")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            LazyVGrid(columns: recentColumns, spacing: 16) {
                ForEach(recentItems) { item in
                    NavigationLink(destination: MemorizeView(item: item)) {
                        MemorizeItemModelRow(item: item)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var emptyStateSection: some View {
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

                Text("Add your first verse to begin memorizing. Use the + button in the sidebar to get started.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

#Preview {
    NavigationStack {
        iPadDashboardView()
    }
}
