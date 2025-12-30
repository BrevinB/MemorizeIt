//
//  MemorizeItApp.swift
//  MemorizeIt
//
//  Created by Brevin Blalock on 7/8/24.
//

import SwiftUI
import SwiftData

@main
struct MemorizeItApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var purchaseManager = PurchaseManager.shared

    init() {
        // Configure RevenueCat on app launch
        PurchaseManager.shared.configure()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MemorizeItemModel.self,
            PracticeSession.self,
            AppStats.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete the old store and create fresh (development only)
            // Remove this in production and use proper schema versioning
            let url = URL.applicationSupportDirectory.appending(path: "default.store")
            try? FileManager.default.removeItem(at: url)

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                RootNavigationView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
