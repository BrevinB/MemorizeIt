//
//  ReviewManager.swift
//  MemorizeIt
//
//  Handles App Store review requests at optimal moments
//

import Foundation
import StoreKit

@MainActor
class ReviewManager: ObservableObject {
    static let shared = ReviewManager()

    // MARK: - Configuration

    /// Minimum number of practice sessions before asking for review
    private let minimumSessions = 5

    /// Minimum days since install before asking
    private let minimumDaysSinceInstall = 3

    /// Minimum days between review requests
    private let daysBetweenRequests = 60

    /// Accuracy threshold for "great session" prompt
    private let greatSessionAccuracy: Double = 90.0

    /// Streak milestones that trigger review prompt
    private let streakMilestones = [7, 14, 30, 60, 100]

    // MARK: - UserDefaults Keys

    private let lastReviewRequestKey = "lastReviewRequestDate"
    private let installDateKey = "appInstallDate"
    private let sessionCountKey = "totalSessionsForReview"
    private let lastPromptedStreakKey = "lastPromptedStreakMilestone"
    private let reviewRequestCountKey = "reviewRequestCount"

    // MARK: - Initialization

    private init() {
        // Set install date if not already set
        if UserDefaults.standard.object(forKey: installDateKey) == nil {
            UserDefaults.standard.set(Date(), forKey: installDateKey)
        }
    }

    // MARK: - Public Methods

    /// Call after a practice session completes with high accuracy
    func recordGreatSession(accuracy: Double) {
        incrementSessionCount()

        guard accuracy >= greatSessionAccuracy else { return }

        // Small delay to let the completion animation play
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.requestReviewIfAppropriate(trigger: "great_session")
        }
    }

    /// Call when user reaches a streak milestone
    func checkStreakMilestone(currentStreak: Int) {
        let lastPromptedMilestone = UserDefaults.standard.integer(forKey: lastPromptedStreakKey)

        // Find the highest milestone reached that we haven't prompted for
        if let milestone = streakMilestones.first(where: { $0 == currentStreak && $0 > lastPromptedMilestone }) {
            UserDefaults.standard.set(milestone, forKey: lastPromptedStreakKey)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.requestReviewIfAppropriate(trigger: "streak_milestone_\(milestone)")
            }
        }
    }

    /// Call when user masters a verse (progress >= 90%)
    func recordVerseMastered() {
        requestReviewIfAppropriate(trigger: "verse_mastered")
    }

    /// Manually request review (e.g., from settings "Rate App" button)
    func requestReviewManually() {
        requestReview()
    }

    // MARK: - Private Methods

    private func incrementSessionCount() {
        let count = UserDefaults.standard.integer(forKey: sessionCountKey)
        UserDefaults.standard.set(count + 1, forKey: sessionCountKey)
    }

    private func requestReviewIfAppropriate(trigger: String) {
        // Check minimum sessions
        let sessionCount = UserDefaults.standard.integer(forKey: sessionCountKey)
        guard sessionCount >= minimumSessions else {
            print("ReviewManager: Not enough sessions (\(sessionCount)/\(minimumSessions))")
            return
        }

        // Check minimum days since install
        if let installDate = UserDefaults.standard.object(forKey: installDateKey) as? Date {
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: installDate, to: Date()).day ?? 0
            guard daysSinceInstall >= minimumDaysSinceInstall else {
                print("ReviewManager: Too soon since install (\(daysSinceInstall)/\(minimumDaysSinceInstall) days)")
                return
            }
        }

        // Check time since last request
        if let lastRequest = UserDefaults.standard.object(forKey: lastReviewRequestKey) as? Date {
            let daysSinceLastRequest = Calendar.current.dateComponents([.day], from: lastRequest, to: Date()).day ?? 0
            guard daysSinceLastRequest >= daysBetweenRequests else {
                print("ReviewManager: Too soon since last request (\(daysSinceLastRequest)/\(daysBetweenRequests) days)")
                return
            }
        }

        // All checks passed - request review
        print("ReviewManager: Requesting review (trigger: \(trigger))")
        requestReview()

        // Update tracking
        UserDefaults.standard.set(Date(), forKey: lastReviewRequestKey)
        let requestCount = UserDefaults.standard.integer(forKey: reviewRequestCountKey)
        UserDefaults.standard.set(requestCount + 1, forKey: reviewRequestCountKey)
    }

    private func requestReview() {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) {
            // Use new API for iOS 18+, fallback to older API for earlier versions
            if #available(iOS 18.0, *) {
                // New StoreKit API
                AppStore.requestReview(in: windowScene)
            } else {
                SKStoreReviewController.requestReview(in: windowScene)
            }
        }
    }

    // MARK: - Debug Helpers

    #if DEBUG
    /// Reset all review tracking (for testing)
    func resetTracking() {
        UserDefaults.standard.removeObject(forKey: lastReviewRequestKey)
        UserDefaults.standard.removeObject(forKey: sessionCountKey)
        UserDefaults.standard.removeObject(forKey: lastPromptedStreakKey)
        UserDefaults.standard.removeObject(forKey: reviewRequestCountKey)
        // Keep install date
        print("ReviewManager: Tracking reset")
    }

    /// Force show review prompt (for testing)
    func forceShowReview() {
        requestReview()
    }
    #endif
}
