//
//  PaywallView.swift
//  MemorizeIt
//
//  Subscription paywall UI
//

import SwiftUI
import RevenueCat

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var selectedPackage: Package?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection

                        // Features list
                        featuresSection
                    }
                    .padding()
                    .padding(.bottom, 8)
                }

                // Fixed bottom section
                VStack(spacing: 16) {
                    Divider()

                    // Pricing options
                    if purchaseManager.isLoading && purchaseManager.offerings == nil {
                        ProgressView()
                            .padding(.vertical, 20)
                    } else {
                        pricingSection
                    }

                    // Subscribe button
                    subscribeButton

                    // Restore & Terms
                    footerSection
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(Color(uiColor: .systemGroupedBackground))
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Upgrade to Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseManager.errorMessage ?? "Something went wrong")
            }
            .onChange(of: purchaseManager.errorMessage) { oldValue, newValue in
                if newValue != nil {
                    showError = true
                }
            }
            .onAppear {
                // Select annual by default (better value)
                if selectedPackage == nil {
                    selectedPackage = purchaseManager.annualPackage ?? purchaseManager.monthlyPackage
                }
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Theme.primary, Theme.primaryLight],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("Unlock Premium")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Memorize without limits")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(spacing: 12) {
            ForEach(premiumFeatures, id: \.title) { feature in
                HStack(spacing: 16) {
                    Image(systemName: feature.icon)
                        .font(.title3)
                        .foregroundColor(Theme.primary)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(feature.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }

    private var premiumFeatures: [(icon: String, title: String, subtitle: String)] {
        [
            ("infinity", "Unlimited Verses", "Add as many verses as you want"),
            ("slider.horizontal.3", "All Difficulty Modes", "Hidden Words & Blank Canvas"),
            ("book.closed.fill", "All Bible Translations", "NIV, ESV, NLT, and more"),
            ("brain.head.profile", "Smart Scheduling", "Spaced repetition for better retention"),
            ("chart.bar.fill", "Detailed Statistics", "Track your progress over time"),
            ("icloud.fill", "iCloud Sync", "Coming Soon")
        ]
    }

    // MARK: - Pricing Section
    private var pricingSection: some View {
        VStack(spacing: 12) {
            if let annual = purchaseManager.annualPackage {
                PricingCard(
                    package: annual,
                    isSelected: selectedPackage?.identifier == annual.identifier,
                    isBestValue: true
                ) {
                    selectedPackage = annual
                    HapticManager.shared.selection()
                }
            }

            if let monthly = purchaseManager.monthlyPackage {
                PricingCard(
                    package: monthly,
                    isSelected: selectedPackage?.identifier == monthly.identifier,
                    isBestValue: false
                ) {
                    selectedPackage = monthly
                    HapticManager.shared.selection()
                }
            }

            // Fallback if no packages loaded
            if purchaseManager.availablePackages.isEmpty && !purchaseManager.isLoading {
                Text("Unable to load subscription options")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }

    // MARK: - Subscribe Button
    private var subscribeButton: some View {
        Button {
            Task {
                guard let package = selectedPackage else { return }
                let success = await purchaseManager.purchase(package)
                if success {
                    dismiss()
                }
            }
        } label: {
            HStack {
                if purchaseManager.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Subscribe Now")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [Theme.primary, Theme.primaryDark],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(selectedPackage == nil || purchaseManager.isLoading)
        .opacity(selectedPackage == nil ? 0.6 : 1)
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(spacing: 16) {
            Button {
                Task {
                    let success = await purchaseManager.restorePurchases()
                    if success {
                        dismiss()
                    }
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(Theme.primary)
            }
            .disabled(purchaseManager.isLoading)

            VStack(spacing: 8) {
                Text("Cancel anytime. Subscription auto-renews until cancelled.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Link("Privacy Policy", destination: URL(string: "https://brevinb.github.io/MemorizeIt-Docs/privacy-policy")!)
                    Text("•")
                    Link("Terms of Use", destination: URL(string: "https://brevinb.github.io/MemorizeIt-Docs/terms-of-service")!)
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Pricing Card Component
struct PricingCard: View {
    let package: Package
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(packageTitle)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(packageSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.localizedPriceString)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(pricePerMonth)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var packageTitle: String {
        switch package.packageType {
        case .annual: return "Annual"
        case .monthly: return "Monthly"
        default: return package.storeProduct.localizedTitle
        }
    }

    private var packageSubtitle: String {
        switch package.packageType {
        case .annual: return "Save over 40%"
        case .monthly: return "Billed monthly"
        default: return ""
        }
    }

    private var pricePerMonth: String {
        switch package.packageType {
        case .annual:
            // Calculate monthly equivalent from annual price
            let annualPrice = package.storeProduct.price as Decimal
            let monthlyPrice = annualPrice / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale.current
            return "\(formatter.string(from: monthlyPrice as NSDecimalNumber) ?? "")/mo"
        case .monthly:
            return "per month"
        default:
            return ""
        }
    }
}

// MARK: - Paywall Trigger Modifier
struct PaywallModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                PaywallView()
            }
    }
}

extension View {
    func paywall(isPresented: Binding<Bool>) -> some View {
        modifier(PaywallModifier(isPresented: isPresented))
    }
}

#Preview {
    PaywallView()
}
