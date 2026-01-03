//
//  Models.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import Foundation
import SwiftData

@Model
final class MemorizeItemModel {
    var id: UUID
    var title: String
    var categoryName: String
    var memorizeText: String
    var isFavorite: Bool
    var createdAt: Date
    var lastPracticedAt: Date?
    var translation: String? // Store Bible translation abbreviation (e.g., "KJV", "NIV")

    // Spaced Repetition (SM-2 Algorithm) fields
    var nextReviewDate: Date? = nil
    var easeFactor: Double = 2.5 // SM-2 ease factor, starts at 2.5
    var intervalDays: Int = 0 // Current interval in days
    var consecutiveCorrect: Int = 0 // Number of correct reviews in a row

    @Relationship(deleteRule: .cascade, inverse: \PracticeSession.item)
    var practiceSessions: [PracticeSession] = []

    var bestAccuracy: Double {
        practiceSessions.map { $0.accuracy }.max() ?? 0.0
    }

    var averageAccuracy: Double {
        guard !practiceSessions.isEmpty else { return 0.0 }
        let total = practiceSessions.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(practiceSessions.count)
    }

    var practiceCount: Int {
        practiceSessions.count
    }

    var progress: Double {
        // Calculate progress based on practice count and accuracy
        let sessionWeight = min(Double(practiceCount) / 10.0, 1.0) // Up to 10 sessions = 100%
        let accuracyWeight = averageAccuracy / 100.0
        return (sessionWeight + accuracyWeight) / 2.0
    }

    /// Returns true if item is due for review (nextReviewDate is today or earlier)
    var isDueForReview: Bool {
        guard let reviewDate = nextReviewDate else {
            // Never practiced - always due
            return true
        }
        return reviewDate <= Date()
    }

    /// Returns days until next review (negative if overdue)
    var daysUntilReview: Int {
        guard let reviewDate = nextReviewDate else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let review = calendar.startOfDay(for: reviewDate)
        return calendar.dateComponents([.day], from: today, to: review).day ?? 0
    }

    init(
        title: String,
        categoryName: String,
        memorizeText: String,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        translation: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.categoryName = categoryName
        self.memorizeText = memorizeText
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.lastPracticedAt = nil
        self.translation = translation
        // Spaced repetition fields use property defaults
    }

    /// Updates spaced repetition schedule based on practice accuracy (SM-2 algorithm)
    /// - Parameter accuracy: Practice accuracy from 0-100
    func updateSpacedRepetition(accuracy: Double) {
        // Convert accuracy (0-100) to SM-2 quality score (0-5)
        // 90-100% = 5 (perfect), 80-89% = 4 (correct with hesitation)
        // 70-79% = 3 (correct with difficulty), 60-69% = 2 (incorrect but remembered)
        // Below 60% = 0-1 (complete blackout)
        let quality: Int
        switch accuracy {
        case 90...100: quality = 5
        case 80..<90: quality = 4
        case 70..<80: quality = 3
        case 60..<70: quality = 2
        case 40..<60: quality = 1
        default: quality = 0
        }

        // SM-2 Algorithm
        if quality >= 3 {
            // Correct response
            consecutiveCorrect += 1

            switch consecutiveCorrect {
            case 1:
                intervalDays = 1
            case 2:
                intervalDays = 6
            default:
                intervalDays = Int(Double(intervalDays) * easeFactor)
            }

            // Update ease factor
            // EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
            let efChange = 0.1 - Double(5 - quality) * (0.08 + Double(5 - quality) * 0.02)
            easeFactor = max(1.3, easeFactor + efChange) // Minimum EF of 1.3
        } else {
            // Incorrect response - reset
            consecutiveCorrect = 0
            intervalDays = 1
            // Don't decrease ease factor below 1.3
            easeFactor = max(1.3, easeFactor - 0.2)
        }

        // Calculate next review date
        let calendar = Calendar.current
        nextReviewDate = calendar.date(byAdding: .day, value: intervalDays, to: Date())
    }
}

@Model
final class PracticeSession {
    var id: UUID
    var date: Date
    var accuracy: Double
    var correctChars: Int
    var totalChars: Int
    var difficultyMode: String
    var timeSpent: TimeInterval

    var item: MemorizeItemModel?

    init(
        accuracy: Double,
        correctChars: Int,
        totalChars: Int,
        difficultyMode: String,
        timeSpent: TimeInterval,
        date: Date = Date()
    ) {
        self.id = UUID()
        self.date = date
        self.accuracy = accuracy
        self.correctChars = correctChars
        self.totalChars = totalChars
        self.difficultyMode = difficultyMode
        self.timeSpent = timeSpent
    }
}

@Model
final class AppStats {
    var id: UUID
    var lastPracticeDate: Date?
    var currentStreak: Int
    var longestStreak: Int
    var totalPracticeSessions: Int
    var totalTimeSpent: TimeInterval

    init() {
        self.id = UUID()
        self.lastPracticeDate = nil
        self.currentStreak = 0
        self.longestStreak = 0
        self.totalPracticeSessions = 0
        self.totalTimeSpent = 0
    }

    func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastPractice = lastPracticeDate {
            let lastPracticeDay = calendar.startOfDay(for: lastPractice)
            let daysDifference = calendar.dateComponents([.day], from: lastPracticeDay, to: today).day ?? 0

            if daysDifference == 0 {
                // Already practiced today, don't increment
                return
            } else if daysDifference == 1 {
                // Practiced yesterday, increment streak
                currentStreak += 1
            } else {
                // Missed a day, reset streak
                currentStreak = 1
            }
        } else {
            // First practice ever
            currentStreak = 1
        }

        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        lastPracticeDate = Date()
    }
}
