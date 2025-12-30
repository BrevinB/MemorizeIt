//
//  BibleAPIService.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import Foundation

enum TranslationSource: Hashable {
    case bibleDotCom  // Free API (bible-api.com)
    case apiBible     // API.Bible (requires key)
}

struct BibleTranslation: Identifiable, Hashable {
    let id: String
    let name: String
    let abbreviation: String
    let source: TranslationSource
    let isFree: Bool // Whether this translation is available to free users

    static let available = [
        // Free translations
        BibleTranslation(id: "de4e12af7f28f599-02", name: "King James Version", abbreviation: "KJV", source: .apiBible, isFree: true),
        BibleTranslation(id: "9879dbb7cfe39e4d-01", name: "New King James Version", abbreviation: "NKJV", source: .apiBible, isFree: true),
        // Premium translations
        BibleTranslation(id: "06125adad2d5898a-01", name: "New International Version", abbreviation: "NIV", source: .apiBible, isFree: false),
        BibleTranslation(id: "65eec8e0b60e656b-01", name: "New American Standard Bible", abbreviation: "NASB", source: .apiBible, isFree: false),
        BibleTranslation(id: "7142879509583d59-01", name: "New Living Translation", abbreviation: "NLT", source: .apiBible, isFree: false),
        BibleTranslation(id: "c315fa9f71d4af3a-01", name: "The Message", abbreviation: "MSG", source: .apiBible, isFree: false)
    ]

    static var freeTranslations: [BibleTranslation] {
        available.filter { $0.isFree }
    }

    static var premiumTranslations: [BibleTranslation] {
        available.filter { !$0.isFree }
    }

    // Fallback translations for when API.Bible hits rate limits
    static let fallbackTranslations: [String: String] = [
        "KJV": "kjv",
        "NKJV": "kjv",
        "MSG": "web"
    ]

    static func == (lhs: BibleTranslation, rhs: BibleTranslation) -> Bool {
        lhs.id == rhs.id && lhs.source == rhs.source
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(abbreviation)
    }
}

struct BibleVerse: Codable, Identifiable {
    let id = UUID()
    let reference: String
    let verses: [VerseDetail]
    let text: String
    let translation_id: String?
    let translation_name: String?

    enum CodingKeys: String, CodingKey {
        case reference, verses, text, translation_id, translation_name
    }
}

struct VerseDetail: Codable {
    let book_id: String
    let book_name: String
    let chapter: Int
    let verse: Int
    let text: String
}

@MainActor
class BibleAPIService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: BibleVerse?
    @Published var selectedTranslation: BibleTranslation {
        didSet {
            // Save preference when changed
            UserDefaults.standard.set(selectedTranslation.id, forKey: "preferredBibleTranslation")
        }
    }

    private let baseURL = "https://bible-api.com/"

    init() {
        // Load saved translation preference
        if let savedTranslationId = UserDefaults.standard.string(forKey: "preferredBibleTranslation"),
           let savedTranslation = BibleTranslation.available.first(where: { $0.id == savedTranslationId }) {
            self.selectedTranslation = savedTranslation
        } else {
            // Default to NIV (first in list)
            self.selectedTranslation = .available[0]
        }
    }

    func searchVerse(reference: String, translation: BibleTranslation? = nil) async {
        isLoading = true
        errorMessage = nil
        searchResults = nil

        // Use provided translation or the selected one
        let translationToUse = translation ?? selectedTranslation

        // Clean up the reference (remove extra spaces, make URL-friendly)
        let cleanedReference = reference
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "+")

        guard let url = URL(string: "\(baseURL)\(cleanedReference)?translation=\(translationToUse.id)") else {
            errorMessage = "Invalid verse reference"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response from server"
                isLoading = false
                return
            }

            if httpResponse.statusCode == 404 {
                errorMessage = "Verse not found. Try a format like 'John 3:16' or 'Romans 8:28'"
                isLoading = false
                return
            }

            guard httpResponse.statusCode == 200 else {
                errorMessage = "Server error. Please try again later."
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            var verse = try decoder.decode(BibleVerse.self, from: data)
            // Clean the text of special Bible formatting characters
            verse = BibleVerse(
                reference: verse.reference,
                verses: verse.verses,
                text: cleanBibleText(verse.text),
                translation_id: verse.translation_id,
                translation_name: verse.translation_name
            )
            searchResults = verse
            isLoading = false

        } catch {
            errorMessage = "Failed to fetch verse. Please check your connection and try again."
            isLoading = false
            print("Error fetching verse: \(error)")
        }
    }

    func clearResults() {
        searchResults = nil
        errorMessage = nil
        isLoading = false
    }

    /// Cleans Bible text of special formatting characters (pilcrow, section signs, etc.)
    private func cleanBibleText(_ text: String) -> String {
        var cleaned = text
        // Remove Bible formatting characters (pilcrow, section signs, daggers, etc.)
        let specialChars = ["¶", "§", "†", "‡", "⁋", "❡", "⸿"]
        for char in specialChars {
            cleaned = cleaned.replacingOccurrences(of: char, with: "")
        }
        // Remove superscript verse numbers (common in some translations)
        cleaned = cleaned.replacingOccurrences(of: "[⁰¹²³⁴⁵⁶⁷⁸⁹]+", with: "", options: .regularExpression)
        // Remove extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Trim
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }
}

// MARK: - Popular Verses Helper
extension BibleAPIService {
    static let popularVerses = [
        "John 3:16",
        "Psalm 23:1-6",
        "Romans 8:28",
        "Philippians 4:13",
        "Proverbs 3:5-6",
        "Jeremiah 29:11",
        "Isaiah 41:10",
        "Matthew 28:19-20",
        "1 Corinthians 13:4-8",
        "Joshua 1:9"
    ]
}
