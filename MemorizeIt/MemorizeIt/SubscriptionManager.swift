//
//  SubscriptionManager.swift
//  MemorizeIt
//
//  Created by Brevin Blalock on 7/8/24.
//

import Foundation
import RevenueCat
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties
    @Published var isSubscribed: Bool = false
    @Published var currentOffering: Offering?
    @Published var customerInfo: CustomerInfo?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Constants
    private let entitlementIdentifier = "premium"

    // MARK: - Initialization
    private init() {}

    // MARK: - Configure RevenueCat
    func configure(apiKey: String) {
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)

        // Set up delegate to listen for customer info updates
        Purchases.shared.delegate = self

        // Fetch initial customer info
        Task {
            await refreshSubscriptionStatus()
            await fetchOfferings()
        }
    }

    // MARK: - Subscription Status
    func refreshSubscriptionStatus() async {
        isLoading = true
        errorMessage = nil

        do {
            let info = try await Purchases.shared.customerInfo()
            self.customerInfo = info
            self.isSubscribed = info.entitlements[entitlementIdentifier]?.isActive == true

            print("[SubscriptionManager] Subscription status refreshed: isSubscribed = \(isSubscribed)")
            if let entitlement = info.entitlements[entitlementIdentifier] {
                print("[SubscriptionManager] Entitlement '\(entitlementIdentifier)': isActive = \(entitlement.isActive)")
            } else {
                print("[SubscriptionManager] No entitlement found for '\(entitlementIdentifier)'")
            }
        } catch {
            print("[SubscriptionManager] Error fetching customer info: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch Offerings
    func fetchOfferings() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            self.currentOffering = offerings.current

            if let offering = offerings.current {
                print("[SubscriptionManager] Fetched offering: \(offering.identifier)")
                print("[SubscriptionManager] Available packages: \(offering.availablePackages.map { $0.identifier })")
            } else {
                print("[SubscriptionManager] No current offering available")
            }
        } catch {
            print("[SubscriptionManager] Error fetching offerings: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Purchase
    func purchase(package: Package) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await Purchases.shared.purchase(package: package)

            // Update customer info immediately after purchase
            self.customerInfo = result.customerInfo
            self.isSubscribed = result.customerInfo.entitlements[entitlementIdentifier]?.isActive == true

            print("[SubscriptionManager] Purchase completed successfully")
            print("[SubscriptionManager] isSubscribed = \(isSubscribed)")

            isLoading = false
            return isSubscribed
        } catch let error as RevenueCat.ErrorCode {
            if error == .purchaseCancelledError {
                print("[SubscriptionManager] User cancelled purchase")
            } else {
                print("[SubscriptionManager] Purchase error: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
            }
            isLoading = false
            return false
        } catch {
            print("[SubscriptionManager] Purchase error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Restore Purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            let info = try await Purchases.shared.restorePurchases()
            self.customerInfo = info
            self.isSubscribed = info.entitlements[entitlementIdentifier]?.isActive == true

            print("[SubscriptionManager] Restore completed")
            print("[SubscriptionManager] isSubscribed = \(isSubscribed)")

            if !isSubscribed {
                errorMessage = "No active subscription found. If you believe this is an error, please contact support."
            }

            isLoading = false
            return isSubscribed
        } catch {
            print("[SubscriptionManager] Restore error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Sync Purchases (Force refresh from Apple)
    func syncPurchases() async {
        isLoading = true
        errorMessage = nil

        do {
            // This forces RevenueCat to sync with Apple's servers
            let info = try await Purchases.shared.syncPurchases()
            self.customerInfo = info
            self.isSubscribed = info.entitlements[entitlementIdentifier]?.isActive == true

            print("[SubscriptionManager] Sync completed")
            print("[SubscriptionManager] isSubscribed = \(isSubscribed)")
        } catch {
            print("[SubscriptionManager] Sync error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - RevenueCat Delegate
extension SubscriptionManager: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            self.isSubscribed = customerInfo.entitlements[self.entitlementIdentifier]?.isActive == true

            print("[SubscriptionManager] Customer info updated via delegate")
            print("[SubscriptionManager] isSubscribed = \(self.isSubscribed)")
        }
    }
}
