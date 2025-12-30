//
//  PaywallView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock on 7/8/24.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subscriptionManager: SubscriptionManager

    @State private var selectedPackage: Package?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        // Features
                        featuresSection

                        // Packages
                        if let offering = subscriptionManager.currentOffering {
                            packagesSection(offering: offering)
                        } else if subscriptionManager.isLoading {
                            ProgressView("Loading...")
                                .padding()
                        } else {
                            Text("Unable to load subscription options")
                                .foregroundColor(.secondary)
                                .padding()

                            Button("Retry") {
                                Task {
                                    await subscriptionManager.fetchOfferings()
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        // Purchase Button
                        purchaseButton

                        // Restore Purchases
                        restoreButton

                        // Terms
                        termsSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Upgrade to Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Notice", isPresented: $showingAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onChange(of: subscriptionManager.isSubscribed) { _, isSubscribed in
                // CRITICAL: Dismiss paywall when subscription becomes active
                if isSubscribed {
                    print("[PaywallView] Subscription activated, dismissing paywall")
                    dismiss()
                }
            }
            .onAppear {
                // Select first package by default
                if selectedPackage == nil,
                   let firstPackage = subscriptionManager.currentOffering?.availablePackages.first {
                    selectedPackage = firstPackage
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock Premium")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Get unlimited access to all features")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }

    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            FeatureRow(icon: "infinity", title: "Unlimited Flashcards", description: "Create as many flashcards as you need")
            FeatureRow(icon: "cloud.fill", title: "Cloud Sync", description: "Access your flashcards on all devices")
            FeatureRow(icon: "chart.bar.fill", title: "Advanced Statistics", description: "Track your learning progress")
            FeatureRow(icon: "paintbrush.fill", title: "Custom Themes", description: "Personalize your experience")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    // MARK: - Packages Section
    private func packagesSection(offering: Offering) -> some View {
        VStack(spacing: 12) {
            ForEach(offering.availablePackages, id: \.identifier) { package in
                PackageOptionView(
                    package: package,
                    isSelected: selectedPackage?.identifier == package.identifier
                ) {
                    selectedPackage = package
                }
            }
        }
    }

    // MARK: - Purchase Button
    private var purchaseButton: some View {
        Button(action: {
            Task {
                await handlePurchase()
            }
        }) {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
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
        .disabled(selectedPackage == nil || isPurchasing)
        .opacity(selectedPackage == nil ? 0.5 : 1)
    }

    // MARK: - Restore Button
    private var restoreButton: some View {
        Button(action: {
            Task {
                await handleRestore()
            }
        }) {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .disabled(isPurchasing)
    }

    // MARK: - Terms Section
    private var termsSection: some View {
        VStack(spacing: 8) {
            Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Terms of Service") {
                    // Open terms URL
                }
                .font(.caption)

                Button("Privacy Policy") {
                    // Open privacy URL
                }
                .font(.caption)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Handlers
    private func handlePurchase() async {
        guard let package = selectedPackage else {
            alertMessage = "Please select a subscription option"
            showingAlert = true
            return
        }

        isPurchasing = true

        let success = await subscriptionManager.purchase(package: package)

        isPurchasing = false

        if success {
            // Paywall will auto-dismiss via onChange handler
            print("[PaywallView] Purchase successful")
        } else if let error = subscriptionManager.errorMessage {
            alertMessage = error
            showingAlert = true
        }
    }

    private func handleRestore() async {
        isPurchasing = true

        let success = await subscriptionManager.restorePurchases()

        isPurchasing = false

        if success {
            // Paywall will auto-dismiss via onChange handler
            alertMessage = "Your subscription has been restored!"
            showingAlert = true
        } else {
            alertMessage = subscriptionManager.errorMessage ?? "No active subscription found"
            showingAlert = true
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Package Option View
struct PackageOptionView: View {
    let package: Package
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(packageTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(package.storeProduct.localizedPriceString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let introPrice = package.storeProduct.introductoryDiscount {
                        Text(introductoryText(for: introPrice))
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var packageTitle: String {
        switch package.packageType {
        case .monthly:
            return "Monthly"
        case .annual:
            return "Annual"
        case .weekly:
            return "Weekly"
        case .lifetime:
            return "Lifetime"
        default:
            return package.identifier
        }
    }

    private func introductoryText(for discount: StoreProductDiscount) -> String {
        switch discount.paymentMode {
        case .freeTrial:
            return "\(discount.subscriptionPeriod.value) \(periodUnit(discount.subscriptionPeriod)) free trial"
        case .payAsYouGo:
            return "Introductory price: \(discount.localizedPriceString)"
        case .payUpFront:
            return "Pay upfront: \(discount.localizedPriceString)"
        @unknown default:
            return ""
        }
    }

    private func periodUnit(_ period: SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return period.value == 1 ? "day" : "days"
        case .week:
            return period.value == 1 ? "week" : "weeks"
        case .month:
            return period.value == 1 ? "month" : "months"
        case .year:
            return period.value == 1 ? "year" : "years"
        @unknown default:
            return ""
        }
    }
}

#Preview {
    PaywallView(subscriptionManager: SubscriptionManager.shared)
}
