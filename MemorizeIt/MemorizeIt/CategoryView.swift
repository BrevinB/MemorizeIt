//
//  CategoryView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock on 10/2/24.
//

import SwiftUI
import SwiftData

enum ProgressFilter: String, CaseIterable {
    case all = "All"
    case new = "New"
    case inProgress = "In Progress"
    case mastered = "Mastered"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .new: return "sparkles"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .mastered: return "checkmark.seal.fill"
        }
    }
}

struct CategoryView: View {
    var selectedCategory: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \MemorizeItemModel.createdAt, order: .reverse) private var allItems: [MemorizeItemModel]

    @State private var searchText: String = ""
    @State private var selectedFilter: ProgressFilter = .all
    @State private var itemToEdit: MemorizeItemModel?
    @State private var showDeleteConfirmation: Bool = false
    @State private var itemToDelete: MemorizeItemModel?
    @State private var showAddNewItem: Bool = false
    @State private var pendingNewItem: MemorizeItemModel?
    @State private var navigateToNewItem: MemorizeItemModel?

    var categoryItems: [MemorizeItemModel] {
        allItems.filter { $0.categoryName == selectedCategory }
    }

    var filteredItems: [MemorizeItemModel] {
        var items = categoryItems

        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.memorizeText.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply progress filter
        switch selectedFilter {
        case .all:
            break
        case .new:
            items = items.filter { $0.practiceCount == 0 }
        case .inProgress:
            items = items.filter { $0.practiceCount > 0 && $0.progress < 0.9 }
        case .mastered:
            items = items.filter { $0.progress >= 0.9 }
        }

        return items
    }

    var filterCounts: [ProgressFilter: Int] {
        [
            .all: categoryItems.count,
            .new: categoryItems.filter { $0.practiceCount == 0 }.count,
            .inProgress: categoryItems.filter { $0.practiceCount > 0 && $0.progress < 0.9 }.count,
            .mastered: categoryItems.filter { $0.progress >= 0.9 }.count
        ]
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 350, maximum: 450), spacing: 16)]
        } else {
            return [GridItem(.flexible())]
        }
    }

    var body: some View {
        Group {
            if categoryItems.isEmpty {
                EmptyStateView.noVerses(category: selectedCategory) {
                    showAddNewItem = true
                }
            } else {
                VStack(spacing: 0) {
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ProgressFilter.allCases, id: \.self) { filter in
                                FilterChip(
                                    filter: filter,
                                    count: filterCounts[filter] ?? 0,
                                    isSelected: selectedFilter == filter
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

                    if filteredItems.isEmpty {
                        Spacer()
                        VStack(spacing: 16) {
                            Image(systemName: searchText.isEmpty ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary.opacity(0.5))

                            Text(searchText.isEmpty ? "No \(selectedFilter.rawValue.lowercased()) items" : "No results for \"\(searchText)\"")
                                .font(.headline)
                                .foregroundColor(.secondary)

                            if !searchText.isEmpty {
                                Button("Clear Search") {
                                    searchText = ""
                                }
                                .font(.subheadline)
                                .foregroundColor(Theme.primary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        Spacer()
                    } else {
                        if horizontalSizeClass == .regular {
                            // iPad: Grid layout with context menus
                            ScrollView {
                                LazyVGrid(columns: gridColumns, spacing: 16) {
                                    ForEach(filteredItems) { item in
                                        NavigationLink(destination: MemorizeView(item: item)) {
                                            VerseCard(item: item)
                                        }
                                        .buttonStyle(ScaleButtonStyle())
                                        .contextMenu {
                                            Button {
                                                withAnimation {
                                                    item.isFavorite.toggle()
                                                    HapticManager.shared.impact(style: .light)
                                                }
                                            } label: {
                                                Label(
                                                    item.isFavorite ? "Remove from Favorites" : "Add to Favorites",
                                                    systemImage: item.isFavorite ? "star.slash" : "star.fill"
                                                )
                                            }

                                            Button {
                                                itemToEdit = item
                                            } label: {
                                                Label("Edit", systemImage: "pencil")
                                            }

                                            Divider()

                                            Button(role: .destructive) {
                                                itemToDelete = item
                                                showDeleteConfirmation = true
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding()
                            }
                        } else {
                            // iPhone: List with swipe actions
                            List {
                                ForEach(filteredItems) { item in
                                    NavigationLink(destination: MemorizeView(item: item)) {
                                        VerseCard(item: item)
                                    }
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            itemToDelete = item
                                            showDeleteConfirmation = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }

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
                }
            }
        }
        .navigationTitle(selectedCategory)
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search \(selectedCategory.lowercased())...")
        .sheet(item: $itemToEdit) { item in
            EditItemView(item: item)
        }
        .navigationDestination(item: $navigateToNewItem) { item in
            MemorizeView(item: item)
        }
        .sheet(isPresented: $showAddNewItem, onDismiss: {
            if let item = pendingNewItem {
                pendingNewItem = nil
                navigateToNewItem = item
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

struct FilterChip: View {
    let filter: ProgressFilter
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.system(size: 12, weight: .medium))

                Text(filter.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSelected
                            ? Color.white.opacity(0.3)
                            : Color.secondary.opacity(0.2)
                    )
                    .cornerRadius(8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Theme.primary
                    : Color(uiColor: .secondarySystemBackground)
            )
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? Color.clear : Color.secondary.opacity(0.2),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct VerseCard: View {
    let item: MemorizeItemModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.categoryColor(for: item.categoryName).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: Theme.categoryIcon(for: item.categoryName))
                        .font(.system(size: 18))
                        .foregroundColor(Theme.categoryColor(for: item.categoryName))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let translation = item.translation {
                        Text(translation)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Progress badge with status icon
                if item.practiceCount == 0 {
                    Label("New", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(8)
                } else if item.progress >= 0.9 {
                    Label("\(Int(item.progress * 100))%", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(8)
                } else if item.progress > 0 {
                    Text("\(Int(item.progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.categoryColor(for: item.categoryName))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.categoryColor(for: item.categoryName).opacity(0.15))
                        .cornerRadius(8)
                }
            }

            Text(item.memorizeText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if item.progress > 0 {
                ProgressView(value: item.progress)
                    .tint(item.progress >= 0.9 ? .green : Theme.categoryColor(for: item.categoryName))
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Edit Item View
struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: MemorizeItemModel

    @State private var title: String = ""
    @State private var memorizeText: String = ""
    @State private var selectedCategory: String = ""
    @State private var isFavorite: Bool = false

    let categories = ["Bible Verses", "Poems", "Speeches"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Title", text: $title)
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            HStack {
                                Image(systemName: Theme.categoryIcon(for: category))
                                    .foregroundColor(Theme.categoryColor(for: category))
                                Text(category)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Text to Memorize") {
                    TextEditor(text: $memorizeText)
                        .frame(minHeight: 200)
                }

                Section {
                    Toggle(isOn: $isFavorite) {
                        Label("Favorite", systemImage: isFavorite ? "star.fill" : "star")
                            .foregroundColor(isFavorite ? .yellow : .primary)
                    }
                }

                if let translation = item.translation {
                    Section("Translation") {
                        Text(translation)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Statistics") {
                    LabeledContent("Practice Sessions", value: "\(item.practiceCount)")
                    LabeledContent("Best Accuracy", value: String(format: "%.0f%%", item.bestAccuracy))
                    LabeledContent("Average Accuracy", value: String(format: "%.0f%%", item.averageAccuracy))
                    if let nextReview = item.nextReviewDate {
                        LabeledContent("Next Review", value: nextReview.formatted(date: .abbreviated, time: .omitted))
                    }
                }
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        HapticManager.shared.notification(type: .success)
                        dismiss()
                    }
                    .disabled(title.isEmpty || memorizeText.isEmpty)
                }
            }
            .onAppear {
                title = item.title
                memorizeText = item.memorizeText
                selectedCategory = item.categoryName
                isFavorite = item.isFavorite
            }
        }
    }

    private func saveChanges() {
        item.title = title
        item.memorizeText = memorizeText
        item.categoryName = selectedCategory
        item.isFavorite = isFavorite
    }
}

#Preview {
    CategoryView(selectedCategory: "Bible Verses")
}
