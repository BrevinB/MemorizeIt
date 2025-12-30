//
//  ContentView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock on 7/8/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @State private var showingPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Premium Status Banner
                premiumStatusBanner

                Spacer()

                // Main content area
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("MemorizeIt")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your personal flashcard companion")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Upgrade button (only show if not subscribed)
                if !subscriptionManager.isSubscribed {
                    upgradeButton
                }
            }
            .padding()
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if subscriptionManager.isSubscribed {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                    }
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(subscriptionManager: subscriptionManager)
            }
            .onAppear {
                // Force refresh subscription status when view appears
                Task {
                    await subscriptionManager.refreshSubscriptionStatus()
                }
            }
        }
    }

    // MARK: - Premium Status Banner
    private var premiumStatusBanner: some View {
        Group {
            if subscriptionManager.isSubscribed {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)

                    Text("Premium Active")
                        .fontWeight(.medium)

                    Spacer()

                    if subscriptionManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else if subscriptionManager.isLoading {
                HStack {
                    ProgressView()
                    Text("Checking subscription...")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Upgrade Button
    private var upgradeButton: some View {
        Button(action: {
            showingPaywall = true
        }) {
            HStack {
                Image(systemName: "crown.fill")
                Text("Upgrade to Premium")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SubscriptionManager.shared)
}
