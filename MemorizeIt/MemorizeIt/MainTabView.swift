//
//  MainTabView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI
import SwiftData

/// Tab identifiers for the iPhone tab bar
enum AppTab: Hashable {
    case home
    case library
    case stats
    case settings
}

/// iPhone root navigation: a standard tab bar so every major destination
/// (Home, Library, Stats, Settings) is always one tap away.
struct MainTabView: View {
    @Query private var allItems: [MemorizeItemModel]
    @State private var selectedTab: AppTab = .home

    private var dueCount: Int {
        allItems.filter { $0.isDueForPractice }.count
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(openStats: { selectedTab = .stats })
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .badge(dueCount)
                .tag(AppTab.home)

            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(AppTab.library)

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(AppTab.stats)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(AppTab.settings)
        }
        .tint(Theme.primary)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [MemorizeItemModel.self, PracticeSession.self, AppStats.self], inMemory: true)
}
