//
//  APIBibleService.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import Foundation

// MARK: - Bolls Bible API Response Models

struct BollsVerseResponse: Codable {
    let pk: Int?
    let translation: String?
    let book: Int?
    let chapter: Int?
    let verse: Int?
    let text: String
}

// MARK: - Bible Reference Parser

struct ParsedBibleReference {
    let bookName: String
    let bookNumber: Int
    let chapter: Int
    let startVerse: Int
    let endVerse: Int?

    var displayReference: String {
        if let end = endVerse, end != startVerse {
            return "\(bookName) \(chapter):\(startVerse)-\(end)"
        }
        return "\(bookName) \(chapter):\(startVerse)"
    }
}

@MainActor
class APIBibleService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchResults: BibleSearchResult?
    @Published var isRateLimited = false

    private let baseURL = "https://bolls.life"

    // Maps lowercase book names (and common abbreviations) to book numbers (1-66)
    private static let bookNameToNumber: [String: Int] = {
        let books: [(Int, [String])] = [
            (1, ["genesis", "gen"]),
            (2, ["exodus", "exod", "exo"]),
            (3, ["leviticus", "lev"]),
            (4, ["numbers", "num"]),
            (5, ["deuteronomy", "deut", "deu"]),
            (6, ["joshua", "josh", "jos"]),
            (7, ["judges", "judg", "jdg"]),
            (8, ["ruth"]),
            (9, ["1 samuel", "1samuel", "1 sam", "1sam"]),
            (10, ["2 samuel", "2samuel", "2 sam", "2sam"]),
            (11, ["1 kings", "1kings", "1 kgs", "1kgs"]),
            (12, ["2 kings", "2kings", "2 kgs", "2kgs"]),
            (13, ["1 chronicles", "1chronicles", "1 chr", "1chr", "1 chron"]),
            (14, ["2 chronicles", "2chronicles", "2 chr", "2chr", "2 chron"]),
            (15, ["ezra"]),
            (16, ["nehemiah", "neh"]),
            (17, ["esther", "esth", "est"]),
            (18, ["job"]),
            (19, ["psalm", "psalms", "psa", "ps"]),
            (20, ["proverbs", "prov", "pro"]),
            (21, ["ecclesiastes", "eccl", "ecc", "eccles"]),
            (22, ["song of solomon", "song of songs", "song", "sos", "ss"]),
            (23, ["isaiah", "isa"]),
            (24, ["jeremiah", "jer"]),
            (25, ["lamentations", "lam"]),
            (26, ["ezekiel", "ezek", "eze"]),
            (27, ["daniel", "dan"]),
            (28, ["hosea", "hos"]),
            (29, ["joel"]),
            (30, ["amos"]),
            (31, ["obadiah", "obad", "oba"]),
            (32, ["jonah", "jon"]),
            (33, ["micah", "mic"]),
            (34, ["nahum", "nah"]),
            (35, ["habakkuk", "hab"]),
            (36, ["zephaniah", "zeph", "zep"]),
            (37, ["haggai", "hag"]),
            (38, ["zechariah", "zech", "zec"]),
            (39, ["malachi", "mal"]),
            (40, ["matthew", "matt", "mat"]),
            (41, ["mark", "mrk"]),
            (42, ["luke", "luk"]),
            (43, ["john", "joh", "jhn"]),
            (44, ["acts"]),
            (45, ["romans", "rom"]),
            (46, ["1 corinthians", "1corinthians", "1 cor", "1cor"]),
            (47, ["2 corinthians", "2corinthians", "2 cor", "2cor"]),
            (48, ["galatians", "gal"]),
            (49, ["ephesians", "eph"]),
            (50, ["philippians", "phil", "php"]),
            (51, ["colossians", "col"]),
            (52, ["1 thessalonians", "1thessalonians", "1 thess", "1thess", "1 thes"]),
            (53, ["2 thessalonians", "2thessalonians", "2 thess", "2thess", "2 thes"]),
            (54, ["1 timothy", "1timothy", "1 tim", "1tim"]),
            (55, ["2 timothy", "2timothy", "2 tim", "2tim"]),
            (56, ["titus", "tit"]),
            (57, ["philemon", "phlm", "phm"]),
            (58, ["hebrews", "heb"]),
            (59, ["james", "jas"]),
            (60, ["1 peter", "1peter", "1 pet", "1pet"]),
            (61, ["2 peter", "2peter", "2 pet", "2pet"]),
            (62, ["1 john", "1john", "1 jn", "1jn"]),
            (63, ["2 john", "2john", "2 jn", "2jn"]),
            (64, ["3 john", "3john", "3 jn", "3jn"]),
            (65, ["jude"]),
            (66, ["revelation", "rev"])
        ]

        var mapping: [String: Int] = [:]
        for (number, names) in books {
            for name in names {
                mapping[name] = number
            }
        }
        return mapping
    }()

    // Canonical book names for display (indexed by book number)
    private static let bookNames: [Int: String] = [
        1: "Genesis", 2: "Exodus", 3: "Leviticus", 4: "Numbers", 5: "Deuteronomy",
        6: "Joshua", 7: "Judges", 8: "Ruth", 9: "1 Samuel", 10: "2 Samuel",
        11: "1 Kings", 12: "2 Kings", 13: "1 Chronicles", 14: "2 Chronicles",
        15: "Ezra", 16: "Nehemiah", 17: "Esther", 18: "Job", 19: "Psalms",
        20: "Proverbs", 21: "Ecclesiastes", 22: "Song of Solomon", 23: "Isaiah",
        24: "Jeremiah", 25: "Lamentations", 26: "Ezekiel", 27: "Daniel",
        28: "Hosea", 29: "Joel", 30: "Amos", 31: "Obadiah", 32: "Jonah",
        33: "Micah", 34: "Nahum", 35: "Habakkuk", 36: "Zephaniah", 37: "Haggai",
        38: "Zechariah", 39: "Malachi", 40: "Matthew", 41: "Mark", 42: "Luke",
        43: "John", 44: "Acts", 45: "Romans", 46: "1 Corinthians",
        47: "2 Corinthians", 48: "Galatians", 49: "Ephesians", 50: "Philippians",
        51: "Colossians", 52: "1 Thessalonians", 53: "2 Thessalonians",
        54: "1 Timothy", 55: "2 Timothy", 56: "Titus", 57: "Philemon",
        58: "Hebrews", 59: "James", 60: "1 Peter", 61: "2 Peter",
        62: "1 John", 63: "2 John", 64: "3 John", 65: "Jude", 66: "Revelation"
    ]

    /// Parses a Bible reference string like "John 3:16" or "1 Corinthians 13:4-8"
    static func parseReference(_ reference: String) -> ParsedBibleReference? {
        let trimmed = reference.trimmingCharacters(in: .whitespacesAndNewlines)

        // Regex to match references like "John 3:16", "1 Corinthians 13:4-8", "Psalm 23:1-6"
        // Captures: book name, chapter, start verse, optional end verse
        guard let regex = try? NSRegularExpression(
            pattern: #"^(.+?)\s+(\d+):(\d+)(?:-(\d+))?$"#,
            options: .caseInsensitive
        ) else { return nil }

        let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = regex.firstMatch(in: trimmed, options: [], range: nsRange) else {
            return nil
        }

        guard let bookRange = Range(match.range(at: 1), in: trimmed),
              let chapterRange = Range(match.range(at: 2), in: trimmed),
              let startVerseRange = Range(match.range(at: 3), in: trimmed) else {
            return nil
        }

        let bookInput = String(trimmed[bookRange]).trimmingCharacters(in: .whitespaces).lowercased()
        guard let chapter = Int(trimmed[chapterRange]),
              let startVerse = Int(trimmed[startVerseRange]) else {
            return nil
        }

        guard let bookNumber = bookNameToNumber[bookInput] else {
            return nil
        }

        let canonicalName = bookNames[bookNumber] ?? String(trimmed[bookRange])

        var endVerse: Int? = nil
        if match.range(at: 4).location != NSNotFound,
           let endVerseRange = Range(match.range(at: 4), in: trimmed) {
            endVerse = Int(trimmed[endVerseRange])
        }

        return ParsedBibleReference(
            bookName: canonicalName,
            bookNumber: bookNumber,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse
        )
    }

    func searchVerse(reference: String, bibleId: String) async {
        isLoading = true
        errorMessage = nil
        searchResults = nil
        isRateLimited = false

        guard let parsed = APIBibleService.parseReference(reference) else {
            errorMessage = "Could not parse reference. Try a format like 'John 3:16'"
            isLoading = false
            return
        }

        if let endVerse = parsed.endVerse, endVerse > parsed.startVerse {
            // Verse range: fetch the whole chapter and filter
            await fetchVerseRange(parsed: parsed, translationId: bibleId)
        } else {
            // Single verse
            await fetchSingleVerse(parsed: parsed, translationId: bibleId)
        }
    }

    private func fetchSingleVerse(parsed: ParsedBibleReference, translationId: String) async {
        let urlString = "\(baseURL)/get-verse/\(translationId)/\(parsed.bookNumber)/\(parsed.chapter)/\(parsed.startVerse)/"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid reference"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

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
                errorMessage = "Verse not found. Try a format like 'John 3:16'"
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            let verseResponse = try decoder.decode(BollsVerseResponse.self, from: data)

            let cleanContent = cleanText(verseResponse.text)

            searchResults = BibleSearchResult(
                reference: parsed.displayReference,
                text: cleanContent
            )
            isLoading = false

        } catch {
            errorMessage = "Failed to fetch verse: \(error.localizedDescription)"
            isLoading = false
            print("Bolls API error: \(error)")
        }
    }

    private func fetchVerseRange(parsed: ParsedBibleReference, translationId: String) async {
        // Fetch the entire chapter, then filter to the verse range
        let urlString = "\(baseURL)/get-text/\(translationId)/\(parsed.bookNumber)/\(parsed.chapter)/"
        guard let url = URL(string: urlString) else {
            errorMessage = "Invalid reference"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

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
            let chapterVerses = try decoder.decode([BollsVerseResponse].self, from: data)

            let startVerse = parsed.startVerse
            let endVerse = parsed.endVerse ?? parsed.startVerse

            // Filter to the requested verse range
            let filteredVerses = chapterVerses.filter { verse in
                guard let verseNum = verse.verse else { return false }
                return verseNum >= startVerse && verseNum <= endVerse
            }

            guard !filteredVerses.isEmpty else {
                errorMessage = "Verse not found. Try a format like 'John 3:16-17'"
                isLoading = false
                return
            }

            // Combine verse texts
            let combinedText = filteredVerses
                .map { cleanText($0.text) }
                .joined(separator: " ")

            searchResults = BibleSearchResult(
                reference: parsed.displayReference,
                text: combinedText
            )
            isLoading = false

        } catch {
            errorMessage = "Failed to fetch verses: \(error.localizedDescription)"
            isLoading = false
            print("Bolls API error: \(error)")
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

struct BibleSearchResult {
    let reference: String
    let text: String
}
