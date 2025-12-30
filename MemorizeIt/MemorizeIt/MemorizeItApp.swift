//
//  MemorizeItApp.swift
//  MemorizeIt
//
//  Created by Brevin Blalock on 7/8/24.
//

import SwiftUI
import RevenueCat

@main
struct MemorizeItApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    init() {
        // IMPORTANT: Configure RevenueCat with your API key
        // Replace with your actual RevenueCat API key from the RevenueCat dashboard
        let apiKey = "your_revenuecat_api_key_here"

        // Configure RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: apiKey)

        // Set up the delegate on the shared instance
        Task { @MainActor in
            SubscriptionManager.shared.configure(apiKey: apiKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(subscriptionManager)
                .task {
                    // Refresh subscription status on app launch
                    await subscriptionManager.refreshSubscriptionStatus()
                    await subscriptionManager.fetchOfferings()
                }
        }
    }
}
