//
//  AddNewItemView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock on 10/3/24.
//

import SwiftUI
import SwiftData

enum AddMode {
    case manual
    case search
}

struct AddNewItemView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext

    @StateObject private var bibleAPI = BibleAPIService()
    @StateObject private var apiBibleService = APIBibleService()
    @StateObject private var purchaseManager = PurchaseManager.shared

    @Query private var allItems: [MemorizeItemModel]

    var onItemAdded: ((MemorizeItemModel) -> Void)?

    @State private var addMode: AddMode = .search
    @State private var searchReference: String = ""
    @State private var title: String = ""
    @State private var selectedCategory: String = "Bible Verses"
    @State private var memorizeText: String = ""
    @State private var showPaywall: Bool = false

    let categories = ["Bible Verses", "Poems", "Speeches"]

    private var canAddMoreVerses: Bool {
        purchaseManager.canAddMoreVerses(currentCount: allItems.count)
    }

    private var versesRemaining: Int {
        purchaseManager.versesRemaining(currentCount: allItems.count)
    }

    var isLoading: Bool {
        bibleAPI.isLoading || apiBibleService.isLoading
    }

    var errorMessage: String? {
        bibleAPI.errorMessage ?? apiBibleService.errorMessage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Limit Banner (for free users)
                    if !purchaseManager.isPremium {
                        HStack(spacing: 12) {
                            Image(systemName: canAddMoreVerses ? "info.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(canAddMoreVerses ? Theme.primary : .orange)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(canAddMoreVerses ? "\(versesRemaining) verses remaining" : "Verse limit reached")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                Text(canAddMoreVerses ? "Free accounts can store up to \(PurchaseManager.freeVerseLimit) verses" : "Upgrade to Premium for unlimited verses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if !canAddMoreVerses {
                                Button("Upgrade") {
                                    showPaywall = true
                                }
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.primary)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(canAddMoreVerses ? Theme.primary.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }

                    // Header Icon
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.15))
                            .frame(width: 80, height: 80)

                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(Theme.primary)
                    }
                    .padding(.top, canAddMoreVerses ? 20 : 8)

                    // Mode Selector
                    Picker("Mode", selection: $addMode) {
                        Text("Search Bible").tag(AddMode.search)
                        Text("Manual Entry").tag(AddMode.manual)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 20) {
                        if addMode == .search {
                            // Bible Verse Search
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Search for a Bible Verse")
                                        .font(.headline)

                                    Spacer()

                                    // Translation Picker
                                    Menu {
                                        // Free translations - always available
                                        Section("Free") {
                                            ForEach(BibleTranslation.freeTranslations) { translation in
                                                Button {
                                                    bibleAPI.selectedTranslation = translation
                                                } label: {
                                                    HStack {
                                                        Text("\(translation.abbreviation) - \(translation.name)")
                                                        if bibleAPI.selectedTranslation.id == translation.id {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Premium translations - locked for free users
                                        Section("Premium") {
                                            ForEach(BibleTranslation.premiumTranslations) { translation in
                                                Button {
                                                    if purchaseManager.isPremium {
                                                        bibleAPI.selectedTranslation = translation
                                                    } else {
                                                        showPaywall = true
                                                    }
                                                } label: {
                                                    HStack {
                                                        Text("\(translation.abbreviation) - \(translation.name)")
                                                        Spacer()
                                                        if !purchaseManager.isPremium {
                                                            Image(systemName: "lock.fill")
                                                                .foregroundColor(.secondary)
                                                        } else if bibleAPI.selectedTranslation.id == translation.id {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(bibleAPI.selectedTranslation.abbreviation)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                        }
                                        .foregroundColor(Theme.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Theme.primary.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                }

                                HStack {
                                    TextField("e.g., John 3:16", text: $searchReference)
                                        .padding()
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.primary.opacity(0.2), lineWidth: 1)
                                        )
                                        .textInputAutocapitalization(.words)
                                        .onSubmit {
                                            Task {
                                                await performSearch()
                                            }
                                        }

                                    Button(action: {
                                        Task {
                                            HapticManager.shared.impact(style: .light)
                                            await performSearch()
                                        }
                                    }) {
                                        Image(systemName: "magnifyingglass")
                                            .padding()
                                            .background(Theme.primary)
                                            .foregroundColor(.white)
                                            .cornerRadius(12)
                                    }
                                    .disabled(searchReference.isEmpty || isLoading)
                                }

                                // Popular verses
                                if bibleAPI.searchResults == nil && apiBibleService.searchResults == nil && !isLoading {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Popular Verses")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)

                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 8) {
                                                ForEach(BibleAPIService.popularVerses, id: \.self) { verse in
                                                    Button(action: {
                                                        searchReference = verse
                                                        Task {
                                                            await performSearch()
                                                        }
                                                    }) {
                                                        Text(verse)
                                                            .font(.caption)
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 6)
                                                            .background(Theme.primary.opacity(0.1))
                                                            .foregroundColor(Theme.primary)
                                                            .cornerRadius(8)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Loading State
                                if isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .padding()
                                        Spacer()
                                    }
                                }

                                // Error Message
                                if let error = errorMessage {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text(error)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(12)
                                }

                                // Search Results - from either API
                                if let verse = bibleAPI.searchResults {
                                    VerseResultCard(
                                        reference: verse.reference,
                                        text: verse.text.trimmingCharacters(in: .whitespacesAndNewlines),
                                        translation: bibleAPI.selectedTranslation.abbreviation,
                                        onAdd: {
                                            HapticManager.shared.impact(style: .light)
                                            title = verse.reference
                                            memorizeText = verse.text.trimmingCharacters(in: .whitespacesAndNewlines)
                                            selectedCategory = "Bible Verses"
                                            saveItemIfAllowed(translation: bibleAPI.selectedTranslation.abbreviation)
                                        }
                                    )
                                } else if let verse = apiBibleService.searchResults {
                                    VerseResultCard(
                                        reference: verse.reference,
                                        text: verse.text,
                                        translation: bibleAPI.selectedTranslation.abbreviation,
                                        onAdd: {
                                            HapticManager.shared.impact(style: .light)
                                            title = verse.reference
                                            memorizeText = verse.text
                                            selectedCategory = "Bible Verses"
                                            saveItemIfAllowed(translation: bibleAPI.selectedTranslation.abbreviation)
                                        }
                                    )
                                }
                            }
                        } else {
                            // Manual Entry Mode
                            VStack(alignment: .leading, spacing: 20) {
                                // Title Field
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Title")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    TextField("e.g., John 3:16", text: $title)
                                        .padding()
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.primary.opacity(0.2), lineWidth: 1)
                                        )
                                }

                                // Category Picker
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Menu {
                                        Picker("Category", selection: $selectedCategory) {
                                            ForEach(categories, id: \.self) { category in
                                                HStack {
                                                    Image(systemName: Theme.categoryIcon(for: category))
                                                    Text(category)
                                                }
                                                .tag(category)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: Theme.categoryIcon(for: selectedCategory))
                                                .foregroundColor(Theme.categoryColor(for: selectedCategory))

                                            Text(selectedCategory)
                                                .foregroundColor(.primary)

                                            Spacer()

                                            Image(systemName: "chevron.down")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Theme.primary.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }

                                // Text Editor
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Text to Memorize")
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    ZStack(alignment: .topLeading) {
                                        if memorizeText.isEmpty {
                                            Text("Enter the text you want to memorize...")
                                                .foregroundColor(.secondary.opacity(0.5))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 12)
                                        }

                                        TextEditor(text: $memorizeText)
                                            .padding(4)
                                            .frame(minHeight: 200)
                                            .scrollContentBackground(.hidden)
                                            .background(Color(uiColor: .secondarySystemBackground))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Theme.primary.opacity(0.2), lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Action Buttons (only show for manual mode, search mode has its own button)
                    if addMode == .manual {
                        VStack(spacing: 12) {
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                saveItemIfAllowed()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Add Item")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Theme.primary)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(title.isEmpty || memorizeText.isEmpty)
                            .opacity(title.isEmpty || memorizeText.isEmpty ? 0.5 : 1.0)

                            Button(action: {
                                dismiss()
                            }) {
                                Text("Cancel")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(Theme.primary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    } else {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(Theme.primary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("New Item")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func saveItemIfAllowed(translation: String? = nil) {
        guard canAddMoreVerses else {
            showPaywall = true
            return
        }
        let newItem = saveItem(translation: translation)
        onItemAdded?(newItem)
        dismiss()
    }

    private func performSearch() async {
        // Clear previous results
        bibleAPI.clearResults()
        apiBibleService.errorMessage = nil
        apiBibleService.searchResults = nil
        apiBibleService.isRateLimited = false

        // Always try API.Bible first for better translations
        await apiBibleService.searchVerse(reference: searchReference, bibleId: bibleAPI.selectedTranslation.id)

        // If rate limited, fallback to free API
        if apiBibleService.isRateLimited {
            // Check if we have a fallback translation
            if let fallbackId = BibleTranslation.fallbackTranslations[bibleAPI.selectedTranslation.abbreviation] {
                print("Falling back to free API with translation: \(fallbackId)")
                apiBibleService.errorMessage = "Using free API (rate limited)..."

                // Wait a moment to show the message
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

                // Use the free API as fallback
                await bibleAPI.searchVerse(reference: searchReference, translation: BibleTranslation(
                    id: fallbackId,
                    name: bibleAPI.selectedTranslation.name,
                    abbreviation: bibleAPI.selectedTranslation.abbreviation,
                    source: .bibleDotCom,
                    isFree: true
                ))
            } else {
                apiBibleService.errorMessage = "Rate limited. This translation has no free fallback."
            }
        }
    }

    @discardableResult
    private func saveItem(translation: String? = nil) -> MemorizeItemModel {
        let newItem = MemorizeItemModel(
            title: title,
            categoryName: selectedCategory,
            memorizeText: memorizeText,
            translation: translation
        )
        modelContext.insert(newItem)

        do {
            try modelContext.save()
        } catch {
            print("Error saving item: \(error)")
        }

        return newItem
    }
}

// MARK: - Verse Result Card Component
struct VerseResultCard: View {
    let reference: String
    let text: String
    let translation: String
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(reference)
                    .font(.headline)
                Spacer()
                Text(translation)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.primary.opacity(0.1))
                    .cornerRadius(6)
            }

            Text(text)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)

            Button(action: onAdd) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Add This Verse")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.primary)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(uiColor: .tertiarySystemBackground))
        .cornerRadius(16)
    }
}

#Preview {
    AddNewItemView()
}
