//
//  PurchaseManager.swift
//  MemorizeIt
//
//  Handles RevenueCat subscription management
//

import Foundation
import RevenueCat
import SwiftUI

@MainActor
class PurchaseManager: NSObject, ObservableObject {
    static let shared = PurchaseManager()

    // MARK: - Published Properties
    @Published var isSubscribed: Bool = false
    @Published var offerings: Offerings?
    @Published var customerInfo: CustomerInfo?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    #if DEBUG
    /// Set to true to simulate premium access during development testing
    @Published var debugOverridePremium: Bool = false
    #endif

    // MARK: - Configuration
    private static let apiKey = "appl_OIRYkiZfDoEZDVnJfOoOrOBwqYp"

    // Entitlement ID configured in RevenueCat
    static let premiumEntitlement = "premium"

    // MARK: - Initialization
    private override init() {
        super.init()
    }

    /// Configure RevenueCat - call this on app launch
    func configure() {
        Purchases.logLevel = .debug // Remove in production
        Purchases.configure(withAPIKey: Self.apiKey)

        // Listen for customer info updates
        Purchases.shared.delegate = self

        // Fetch initial state
        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }
    }

    // MARK: - Subscription Status

    /// Check if user has premium access
    var isPremium: Bool {
        #if DEBUG
        if debugOverridePremium { return true }
        #endif
        return customerInfo?.entitlements[Self.premiumEntitlement]?.isActive == true
    }

    /// Refresh customer info from RevenueCat
    func refreshCustomerInfo() async {
        do {
            customerInfo = try await Purchases.shared.customerInfo()
            isSubscribed = isPremium
        } catch {
            print("Error fetching customer info: \(error)")
            errorMessage = "Failed to load subscription status"
        }
    }

    // MARK: - Offerings

    /// Fetch available subscription packages
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            offerings = try await Purchases.shared.offerings()
        } catch {
            print("Error fetching offerings: \(error)")
            errorMessage = "Failed to load subscription options"
        }
    }

    /// Get the current offering's available packages
    var availablePackages: [Package] {
        offerings?.current?.availablePackages ?? []
    }

    /// Get monthly package if available
    var monthlyPackage: Package? {
        offerings?.current?.monthly
    }

    /// Get annual package if available
    var annualPackage: Package? {
        offerings?.current?.annual
    }

    // MARK: - Purchases

    /// Purchase a package
    func purchase(_ package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            customerInfo = result.customerInfo
            isSubscribed = isPremium

            if isPremium {
                HapticManager.shared.notification(type: .success)
                return true
            }
            return false
        } catch let error as ErrorCode {
            if error == .purchaseCancelledError {
                // User cancelled - not an error
                return false
            }
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            HapticManager.shared.notification(type: .error)
            return false
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            HapticManager.shared.notification(type: .error)
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            isSubscribed = isPremium

            if isPremium {
                HapticManager.shared.notification(type: .success)
                return true
            } else {
                errorMessage = "No active subscription found"
                return false
            }
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
            HapticManager.shared.notification(type: .error)
            return false
        }
    }

    // MARK: - Subscription Details

    /// Get expiration date of current subscription
    var expirationDate: Date? {
        customerInfo?.entitlements[Self.premiumEntitlement]?.expirationDate
    }

    /// Check if subscription will renew
    var willRenew: Bool {
        customerInfo?.entitlements[Self.premiumEntitlement]?.willRenew ?? false
    }

    /// Get management URL for subscription
    var managementURL: URL? {
        customerInfo?.managementURL
    }
}

// MARK: - RevenueCat Delegate
extension PurchaseManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.isSubscribed = self.isPremium
        }
    }
}

// MARK: - Premium Feature Checking
extension PurchaseManager {
    /// Feature flags for premium features
    enum PremiumFeature {
        case unlimitedVerses
        case allDifficultyModes
        case allTranslations
        case spacedRepetition
        case detailedStats
        case iCloudSync
        case customCategories
        case widgets

        var displayName: String {
            switch self {
            case .unlimitedVerses: return "Unlimited Verses"
            case .allDifficultyModes: return "All Difficulty Modes"
            case .allTranslations: return "All Bible Translations"
            case .spacedRepetition: return "Smart Review Scheduling"
            case .detailedStats: return "Detailed Statistics"
            case .iCloudSync: return "iCloud Sync"
            case .customCategories: return "Custom Categories"
            case .widgets: return "Home Screen Widgets"
            }
        }

        var icon: String {
            switch self {
            case .unlimitedVerses: return "infinity"
            case .allDifficultyModes: return "slider.horizontal.3"
            case .allTranslations: return "book.closed.fill"
            case .spacedRepetition: return "brain.head.profile"
            case .detailedStats: return "chart.bar.fill"
            case .iCloudSync: return "icloud.fill"
            case .customCategories: return "folder.badge.plus"
            case .widgets: return "square.grid.2x2"
            }
        }
    }

    /// Check if a specific feature is available
    func hasAccess(to feature: PremiumFeature) -> Bool {
        // All features require premium
        return isPremium
    }
}

// MARK: - Free Tier Limits
extension PurchaseManager {
    /// Maximum verses allowed for free users
    static let freeVerseLimit = 10

    /// Check if user can add more verses
    func canAddMoreVerses(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < Self.freeVerseLimit
    }

    /// Verses remaining for free users
    func versesRemaining(currentCount: Int) -> Int {
        if isPremium { return Int.max }
        return max(0, Self.freeVerseLimit - currentCount)
    }
}
