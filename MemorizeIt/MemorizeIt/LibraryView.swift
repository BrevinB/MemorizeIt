//
//  LibraryView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//
//  One place to browse everything: global search across all items,
//  category/favorites filter chips, and sorting. Replaces the need to
//  drill into individual categories to find a verse on iPhone.
//

import SwiftUI
import SwiftData

enum LibraryFilter: Hashable {
    case all
    case favorites
    case category(String)

    var title: String {
        switch self {
        case .all: return "All"
        case .favorites: return "Favorites"
        case .category(let name): return name
        }
    }

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .favorites: return "star.fill"
        case .category(let name): return Theme.categoryIcon(for: name)
        }
    }

    var color: Color {
        switch self {
        case .all: return Theme.primary
        case .favorites: return .orange
        case .category(let name): return Theme.categoryColor(for: name)
        }
    }
}

enum LibrarySort: String, CaseIterable {
    case newest = "Newest First"
    case title = "Title A-Z"
    case progress = "Least Progress"
    case dueFirst = "Due First"

    var icon: String {
        switch self {
        case .newest: return "clock"
        case .title: return "textformat"
        case .progress: return "chart.bar"
        case .dueFirst: return "bell.badge"
        }
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemorizeItemModel.createdAt, order: .reverse) private var allItems: [MemorizeItemModel]
    @StateObject private var categoryStore = CategoryStore.shared

    @State private var searchText: String = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var sortOrder: LibrarySort = .newest
    @State private var path = NavigationPath()
    @State private var showAddNewItem: Bool = false
    @State private var pendingNewItem: MemorizeItemModel?
    @State private var itemToEdit: MemorizeItemModel?
    @State private var itemToDelete: MemorizeItemModel?
    @State private var showDeleteConfirmation: Bool = false

    private var filters: [LibraryFilter] {
        let base: [LibraryFilter] = [.all, .favorites]
        return base + categoryStore.allCategories.map { LibraryFilter.category($0) }
    }

    /// The selected filter, falling back to All if the selected category was
    /// deleted while this tab stayed alive.
    private var effectiveFilter: LibraryFilter {
        if case .category(let name) = selectedFilter,
           !categoryStore.allCategories.contains(name) {
            return .all
        }
        return selectedFilter
    }

    private func items(matching filter: LibraryFilter) -> [MemorizeItemModel] {
        switch filter {
        case .all:
            return allItems
        case .favorites:
            return allItems.filter { $0.isFavorite }
        case .category(let name):
            return allItems.filter { $0.categoryName == name }
        }
    }

    private var filteredItems: [MemorizeItemModel] {
        var items = items(matching: effectiveFilter)

        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.memorizeText.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch sortOrder {
        case .newest:
            break // @Query already sorts by createdAt descending
        case .title:
            items = items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .progress:
            // Compute each sort key once; progress traverses practice sessions
            items = items.map { ($0, $0.progress) }
                .sorted { $0.1 < $1.1 }
                .map { $0.0 }
        case .dueFirst:
            // Never-practiced items have no review date; rank them last so the
            // real review queue comes first
            items = items.map { ($0, $0.nextReviewDate == nil ? Int.max : $0.daysUntilReview) }
                .sorted { $0.1 < $1.1 }
                .map { $0.0 }
        }

        return items
    }

    var body: some View {
        let visibleItems = filteredItems

        return NavigationStack(path: $path) {
            Group {
                if allItems.isEmpty {
                    EmptyStateView(
                        icon: "books.vertical",
                        title: "Your Library Is Empty",
                        message: "Everything you add will live here. Add your first verse to get started.",
                        actionTitle: "Add Your First Verse",
                        action: { showAddNewItem = true }
                    )
                } else {
                    VStack(spacing: 0) {
                        filterChips

                        if visibleItems.isEmpty {
                            if searchText.isEmpty {
                                ContentUnavailableView(
                                    "No \(effectiveFilter.title) Items",
                                    systemImage: effectiveFilter.icon,
                                    description: Text("Nothing matches this filter yet.")
                                )
                            } else {
                                ContentUnavailableView.search(text: searchText)
                            }
                        } else {
                            itemList(visibleItems)
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search all verses...")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("Sort", selection: $sortOrder) {
                            ForEach(LibrarySort.allCases, id: \.self) { sort in
                                Label(sort.rawValue, systemImage: sort.icon)
                                    .tag(sort)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.title3)
                            .foregroundColor(Theme.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.impact(style: .light)
                        showAddNewItem = true
                    } label: {
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
            .sheet(item: $itemToEdit) { item in
                EditItemView(item: item)
            }
            .sheet(isPresented: $showAddNewItem, onDismiss: {
                if let item = pendingNewItem {
                    pendingNewItem = nil
                    path.append(item)
                }
            }) {
                AddNewItemView(onItemAdded: { newItem in
                    pendingNewItem = newItem
                })
            }
            .alert("Delete Item", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    itemToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let item = itemToDelete {
                        withAnimation {
                            modelContext.delete(item)
                            HapticManager.shared.notification(type: .success)
                        }
                    }
                    itemToDelete = nil
                }
            } message: {
                Text("Are you sure you want to delete \"\(itemToDelete?.title ?? "this item")\"? This cannot be undone.")
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(
                        title: filter.title,
                        icon: filter.icon,
                        count: items(matching: filter).count,
                        isSelected: effectiveFilter == filter,
                        selectedColor: filter.color
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedFilter = filter
                        }
                        HapticManager.shared.selection()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private func itemList(_ items: [MemorizeItemModel]) -> some View {
        List {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    VerseCard(item: item)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // No destructive role: the delete is confirmed via alert, and
                    // a destructive-role button would animate the row away even
                    // when the user cancels
                    Button {
                        itemToDelete = item
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)

                    Button {
                        itemToEdit = item
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        withAnimation {
                            item.isFavorite.toggle()
                            HapticManager.shared.impact(style: .light)
                        }
                    } label: {
                        Label(
                            item.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: item.isFavorite ? "star.slash" : "star.fill"
                        )
                    }
                    .tint(.yellow)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [MemorizeItemModel.self, PracticeSession.self, AppStats.self], inMemory: true)
}
