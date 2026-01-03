//
//  SidebarView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI
import SwiftData

/// iPad sidebar navigation view
struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [MemorizeItemModel]
    @State private var showAddNewItem = false

    private var dueCount: Int {
        allItems.filter { $0.isDueForReview }.count
    }

    private var favoritesCount: Int {
        allItems.filter { $0.isFavorite }.count
    }

    private func categoryCount(for item: SidebarItem) -> Int {
        let categoryName: String
        switch item {
        case .bibleVerses: categoryName = "Bible Verses"
        case .poems: categoryName = "Poems"
        case .speeches: categoryName = "Speeches"
        default: return 0
        }
        return allItems.filter { $0.categoryName == categoryName }.count
    }

    var body: some View {
        List(selection: $selection) {
            // Header with branding
            Section {
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.largeTitle)
                        .foregroundColor(Theme.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MemorizeIt")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Master memorization")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Main Navigation
            Section("Navigation") {
                Label {
                    HStack {
                        Text(SidebarItem.dashboard.rawValue)
                        Spacer()
                        if dueCount > 0 {
                            Text("\(dueCount)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(10)
                        }
                    }
                } icon: {
                    Image(systemName: SidebarItem.dashboard.icon)
                        .foregroundColor(SidebarItem.dashboard.color)
                }
                .tag(SidebarItem.dashboard)
            }

            // Categories
            Section("Categories") {
                ForEach([SidebarItem.bibleVerses, .poems, .speeches], id: \.self) { item in
                    Label {
                        HStack {
                            Text(item.rawValue)
                            Spacer()
                            Text("\(categoryCount(for: item))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: item.icon)
                            .foregroundColor(item.color)
                    }
                    .tag(item)
                }
            }

            // Collections
            Section("Collections") {
                Label {
                    HStack {
                        Text(SidebarItem.favorites.rawValue)
                        Spacer()
                        if favoritesCount > 0 {
                            Text("\(favoritesCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: SidebarItem.favorites.icon)
                        .foregroundColor(SidebarItem.favorites.color)
                }
                .tag(SidebarItem.favorites)
            }

            // App
            Section("App") {
                Label(SidebarItem.statistics.rawValue, systemImage: SidebarItem.statistics.icon)
                    .tag(SidebarItem.statistics)

                Label(SidebarItem.settings.rawValue, systemImage: SidebarItem.settings.icon)
                    .tag(SidebarItem.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MemorizeIt")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddNewItem = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .sheet(isPresented: $showAddNewItem) {
            AddNewItemView()
        }
    }
}

#Preview {
    NavigationSplitView {
        SidebarView(selection: .constant(.dashboard))
    } detail: {
        Text("Detail")
    }
}
