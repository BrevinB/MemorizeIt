//
//  APIBibleService.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import Foundation

// IMPORTANT: Keep this API key secure! Don't commit to public repositories
private let API_BIBLE_KEY = "d8bea199310d362b1a34ebf77015e6b5"

struct APIBibleVerse: Codable {
    let data: APIBibleVerseData
}

struct APIBibleVerseData: Codable {
    let id: String
    let bibleId: String?
    let bookId: String?
    let chapterId: String?
    let content: String
    let reference: String
    let verseCount: Int?
    let copyright: String?
}

@MainActor
class APIBibleService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: BibleSearchResult?
    @Published var isRateLimited = false

    private let baseURL = "https://api.scripture.api.bible/v1"

    func searchVerse(reference: String, bibleId: String) async {
        isLoading = true
        errorMessage = nil
        searchResults = nil

        // Check if this is a verse range (contains a dash like "John 3:16-17")
        let isRange = reference.contains("-") && reference.contains(":")

        if isRange {
            // For ranges, fetch using verses endpoint with multiple verse IDs
            await fetchVerseRange(reference: reference, bibleId: bibleId)
        } else {
            // For single verses, use search
            await searchSingleVerse(reference: reference, bibleId: bibleId)
        }
    }

    private func searchSingleVerse(reference: String, bibleId: String) async {
        // Use search endpoint to find the verse
        guard let searchURL = URL(string: "\(baseURL)/bibles/\(bibleId)/search?query=\(reference.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&limit=1") else {
            errorMessage = "Invalid reference"
            isLoading = false
            return
        }

        var request = URLRequest(url: searchURL)
        request.setValue(API_BIBLE_KEY, forHTTPHeaderField: "api-key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                isLoading = false
                return
            }

            if httpResponse.statusCode == 401 {
                errorMessage = "API key error. Please check configuration."
                isLoading = false
                print("API.Bible: 401 Unauthorized - API key may be invalid")
                return
            }

            if httpResponse.statusCode == 429 {
                isRateLimited = true
                errorMessage = "Rate limit reached. Falling back to free API..."
                isLoading = false
                print("API.Bible: 429 Rate Limited - will fallback")
                return
            }

            if httpResponse.statusCode == 403 {
                errorMessage = "This translation may not be available with your API key."
                isLoading = false
                print("API.Bible: 403 Forbidden - Translation not accessible")
                return
            }

            if httpResponse.statusCode != 200 {
                errorMessage = "Verse not found. Try a format like 'John 3:16'"
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(APIBibleSearchResponse.self, from: data)

            guard let firstResult = searchResponse.data.passages.first else {
                errorMessage = "Verse not found. Try a format like 'John 3:16'"
                isLoading = false
                return
            }

            // Fetch the passage content
            await fetchPassage(passageId: firstResult.id, bibleId: bibleId)

        } catch {
            errorMessage = "Failed to search verse: \(error.localizedDescription)"
            isLoading = false
            print("API.Bible search error: \(error)")
        }
    }

    private func fetchVerseRange(reference: String, bibleId: String) async {
        // For verse ranges, use the verses endpoint to get multiple verses
        // First, search to find the chapter, then get the verse range
        guard let searchURL = URL(string: "\(baseURL)/bibles/\(bibleId)/search?query=\(reference.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            errorMessage = "Invalid reference"
            isLoading = false
            return
        }

        var request = URLRequest(url: searchURL)
        request.setValue(API_BIBLE_KEY, forHTTPHeaderField: "api-key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                errorMessage = "Invalid response"
                isLoading = false
                return
            }

            if httpResponse.statusCode == 429 {
                isRateLimited = true
                errorMessage = "Rate limit reached. Falling back to free API..."
                isLoading = false
                return
            }

            if httpResponse.statusCode != 200 {
                errorMessage = "Verse not found. Try a format like 'John 3:16-17'"
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            let searchResponse = try decoder.decode(APIBibleSearchResponse.self, from: data)

            // Get all passages from search and combine them
            if !searchResponse.data.passages.isEmpty {
                await fetchMultiplePassages(passages: searchResponse.data.passages, bibleId: bibleId)
            } else {
                errorMessage = "Verse not found. Try a format like 'John 3:16-17'"
                isLoading = false
            }

        } catch {
            errorMessage = "Failed to search verse: \(error.localizedDescription)"
            isLoading = false
            print("API.Bible search error: \(error)")
        }
    }

    private func fetchMultiplePassages(passages: [APIBiblePassageReference], bibleId: String) async {
        // Fetch the first passage (which should contain the range if search found it)
        guard let firstPassage = passages.first else {
            errorMessage = "No passages found"
            isLoading = false
            return
        }

        await fetchPassage(passageId: firstPassage.id, bibleId: bibleId)
    }

    private func fetchPassage(passageId: String, bibleId: String) async {
        guard let url = URL(string: "\(baseURL)/bibles/\(bibleId)/passages/\(passageId)?content-type=text&include-notes=false&include-titles=false&include-chapter-numbers=false&include-verse-numbers=false&include-verse-spans=false") else {
            errorMessage = "Invalid passage ID"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.setValue(API_BIBLE_KEY, forHTTPHeaderField: "api-key")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "Failed to fetch passage"
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            let passageResponse = try decoder.decode(APIBibleVerse.self, from: data)

            // Clean up the content (remove HTML tags and extra whitespace)
            let cleanContent = cleanText(passageResponse.data.content)

            searchResults = BibleSearchResult(
                reference: passageResponse.data.reference,
                text: cleanContent
            )

            isLoading = false

        } catch {
            errorMessage = "Failed to fetch passage: \(error.localizedDescription)"
            isLoading = false
            print("API.Bible passage error: \(error)")
        }
    }

    private func cleanText(_ html: String) -> String {
        var text = html
        // Remove HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Remove Bible formatting characters (pilcrow, section signs, daggers, etc.)
        let specialChars = ["¶", "§", "†", "‡", "⁋", "❡", "⸿"]
        for char in specialChars {
            text = text.replacingOccurrences(of: char, with: "")
        }
        // Remove superscript verse numbers (common in some translations)
        text = text.replacingOccurrences(of: "[⁰¹²³⁴⁵⁶⁷⁸⁹]+", with: "", options: .regularExpression)
        // Remove extra whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // Trim
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text
    }
}

struct APIBibleSearchResponse: Codable {
    let data: APIBibleSearchData
}

struct APIBibleSearchData: Codable {
    let passages: [APIBiblePassageReference]
}

struct APIBiblePassageReference: Codable {
    let id: String
    let bibleId: String
}

struct BibleSearchResult {
    let reference: String
    let text: String
}
