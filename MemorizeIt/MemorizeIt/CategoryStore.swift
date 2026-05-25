//
//  CategoryStore.swift
//  MemorizeIt
//
//  User-customizable category list. Built-in categories are always present;
//  user-added ones are persisted to UserDefaults. We use UserDefaults rather
//  than SwiftData so we don't need a schema migration for the existing
//  MemorizeItemModel.categoryName string column.
//

import Foundation
import SwiftUI

@MainActor
final class CategoryStore: ObservableObject {
    static let shared = CategoryStore()

    /// Always-present built-in categories. Cannot be deleted or renamed.
    static let builtInCategories: [String] = ["Bible Verses", "Poems", "Speeches"]

    private let customKey = "customCategories"

    @Published private(set) var customCategories: [String] = []

    var allCategories: [String] {
        Self.builtInCategories + customCategories
    }

    private init() {
        if let stored = UserDefaults.standard.array(forKey: customKey) as? [String] {
            customCategories = stored
        }
    }

    func isBuiltIn(_ name: String) -> Bool {
        Self.builtInCategories.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Adds a new custom category. Returns an error message on failure, nil on success.
    @discardableResult
    func add(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Category name cannot be empty" }
        guard trimmed.count <= 40 else { return "Category name is too long" }
        guard !allCategories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return "A category with that name already exists"
        }
        customCategories.append(trimmed)
        persist()
        return nil
    }

    /// Removes a custom category. Built-in categories cannot be removed.
    /// Caller is responsible for checking that no items use the category.
    func remove(_ name: String) {
        guard !isBuiltIn(name) else { return }
        customCategories.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(customCategories, forKey: customKey)
    }
}
