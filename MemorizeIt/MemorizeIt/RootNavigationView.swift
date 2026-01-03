//
//  RootNavigationView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI
import SwiftData

/// Navigation item for the iPad sidebar
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case bibleVerses = "Bible Verses"
    case poems = "Poems"
    case speeches = "Speeches"
    case favorites = "Favorites"
    case statistics = "Statistics"
    case settings = "Settings"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .bibleVerses: return "book.closed.fill"
        case .poems: return "text.quote"
        case .speeches: return "mic.fill"
        case .favorites: return "star.fill"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return Theme.primary
        case .bibleVerses: return Theme.bibleVerse
        case .poems: return Theme.poem
        case .speeches: return Theme.speech
        case .favorites: return .yellow
        case .statistics: return .purple
        case .settings: return .gray
        }
    }
}

/// Main navigation coordinator that switches between iPhone and iPad layouts
struct RootNavigationView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedSidebarItem: SidebarItem? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: NavigationSplitView with sidebar
            iPadNavigationView
        } else {
            // iPhone: Original HomeView with NavigationStack
            HomeView()
        }
    }

    private var iPadNavigationView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $selectedSidebarItem)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSidebarItem {
        case .dashboard:
            NavigationStack {
                iPadDashboardView()
            }
        case .bibleVerses:
            NavigationStack {
                CategoryView(selectedCategory: "Bible Verses")
            }
        case .poems:
            NavigationStack {
                CategoryView(selectedCategory: "Poems")
            }
        case .speeches:
            NavigationStack {
                CategoryView(selectedCategory: "Speeches")
            }
        case .favorites:
            NavigationStack {
                FavoritesView()
            }
        case .statistics:
            NavigationStack {
                StatsView()
            }
        case .settings:
            NavigationStack {
                SettingsView()
            }
        case .none:
            ContentUnavailableView(
                "Select an Item",
                systemImage: "sidebar.left",
                description: Text("Choose a category from the sidebar")
            )
        }
    }
}

#Preview {
    RootNavigationView()
}
