//
//  FavoritesView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI
import SwiftData

/// Dedicated view for displaying favorite items
struct FavoritesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MemorizeItemModel> { $0.isFavorite }, sort: \MemorizeItemModel.createdAt, order: .reverse)
    private var favoriteItems: [MemorizeItemModel]

    @State private var itemToDelete: MemorizeItemModel?
    @State private var showDeleteConfirmation = false

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .regular {
            return [GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)]
        } else {
            return [GridItem(.flexible())]
        }
    }

    var body: some View {
        Group {
            if favoriteItems.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star.slash",
                    description: Text("Mark items as favorites to see them here. Swipe right on any verse to add it to your favorites.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 16) {
                        ForEach(favoriteItems) { item in
                            NavigationLink(destination: MemorizeView(item: item)) {
                                FavoriteItemCard(item: item)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .contextMenu {
                                Button {
                                    item.isFavorite = false
                                } label: {
                                    Label("Remove from Favorites", systemImage: "star.slash")
                                }

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
            }
        }
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Delete Item",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    modelContext.delete(item)
                }
                itemToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                itemToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this item? This action cannot be undone.")
        }
    }
}

/// Card component for favorite items
struct FavoriteItemCard: View {
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

                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)

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

            VStack(alignment: .trailing, spacing: 4) {
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

                if item.isDueForReview {
                    Text("Due")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
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

#Preview {
    NavigationStack {
        FavoritesView()
    }
}
