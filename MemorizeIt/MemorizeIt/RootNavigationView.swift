//
//  RootNavigationView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI
import SwiftData

/// Navigation item for the iPad sidebar. Categories are dynamic (driven by
/// CategoryStore) so we use an associated value rather than a CaseIterable enum.
enum SidebarItem: Hashable, Identifiable {
    case dashboard
    case category(String)
    case favorites
    case statistics
    case settings

    var id: String {
        switch self {
        case .dashboard: return "dashboard"
        case .category(let name): return "category:\(name)"
        case .favorites: return "favorites"
        case .statistics: return "statistics"
        case .settings: return "settings"
        }
    }

    var displayName: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .category(let name): return name
        case .favorites: return "Favorites"
        case .statistics: return "Statistics"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "house.fill"
        case .category(let name): return Theme.categoryIcon(for: name)
        case .favorites: return "star.fill"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return Theme.primary
        case .category(let name): return Theme.categoryColor(for: name)
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
    @State private var navigateToNewItem: MemorizeItemModel?
    @State private var detailPath = NavigationPath()

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
            SidebarView(selection: $selectedSidebarItem, onItemAdded: { newItem in
                navigateToNewItem = newItem
            })
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: navigateToNewItem) { _, newItem in
            if let item = newItem {
                navigateToNewItem = nil
                selectedSidebarItem = .dashboard
                // Delay to allow the detail view to rebuild after sidebar selection change
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    detailPath.append(item)
                }
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSidebarItem {
        case .dashboard:
            NavigationStack(path: $detailPath) {
                iPadDashboardView()
                    .navigationDestination(for: MemorizeItemModel.self) { item in
                        MemorizeView(item: item)
                    }
            }
        case .category(let name):
            NavigationStack {
                CategoryView(selectedCategory: name)
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
