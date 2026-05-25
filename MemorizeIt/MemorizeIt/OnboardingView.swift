//
//  OnboardingView.swift
//  MemorizeIt
//

import SwiftUI
import SwiftData

/// Stage machine for the onboarding flow.
///
/// Order: carousel → demo (interactive memorize) → demoComplete (small win
/// screen) → paywall sheet → seed first verse → main app.
enum OnboardingStage {
    case carousel
    case demo
    case demoComplete
}

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Environment(\.modelContext) private var modelContext

    @State private var stage: OnboardingStage = .carousel
    @State private var currentPage = 0
    @State private var showPaywall = false

    // Demo state
    @State private var demoTypedText: String = ""
    @State private var demoStartTime: Date = Date()
    @State private var demoAccuracy: Double = 0
    @State private var demoSettings: TypingSettings = TypingSettings.load()

    // The verse we use for the interactive demo. Full KJV text so the label
    // matches the content (and so the seeded verse the user keeps is complete).
    private let demoTitle = "John 3:16"
    private let demoVerse = "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life."
    private let demoTranslation = "KJV"

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "brain.head.profile",
            title: "Welcome to MemorizeIt",
            subtitle: "Build lasting memory through deliberate typing practice",
            color: Theme.primary
        ),
        OnboardingPage(
            icon: "book.closed.fill",
            title: "Add Verses & Texts",
            subtitle: "Search any Bible verse or paste your own poems, speeches, and quotes",
            color: .blue
        ),
        OnboardingPage(
            icon: "keyboard",
            title: "Practice by Typing",
            subtitle: "Type with real-time feedback. Multiple difficulty modes help you go from beginner to mastery",
            color: .green
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "Let's Try It",
            subtitle: "Type along with John 3:16 to see how MemorizeIt works. Take your time — you can skip whenever.",
            color: .orange
        )
    ]

    var body: some View {
        Group {
            switch stage {
            case .carousel:
                carouselView
            case .demo:
                demoView
            case .demoComplete:
                demoCompleteView
            }
        }
        .background(Color(uiColor: .systemBackground))
        .sheet(isPresented: $showPaywall, onDismiss: {
            finishOnboarding()
        }) {
            PaywallView()
        }
    }

    // MARK: - Carousel (3 info pages + 1 "let's try" page)

    private var carouselView: some View {
        VStack(spacing: 0) {
            // Skip button - bypasses everything including demo
            HStack {
                Spacer()
                Button("Skip") {
                    completeOnboardingSkippingDemo()
                }
                .foregroundColor(.secondary)
                .padding()
            }

            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Theme.primary : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: currentPage)
                }
            }
            .padding(.bottom, 32)

            Button(action: handleCarouselContinue) {
                Text(currentPage < pages.count - 1 ? "Continue" : "Try It Out")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primary)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func handleCarouselContinue() {
        if currentPage < pages.count - 1 {
            withAnimation { currentPage += 1 }
        } else {
            // User finished the carousel - kick off the demo
            startDemo()
        }
    }

    // MARK: - Demo (interactive)

    private var demoView: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: skipDemo) {
                    Text("Skip Demo")
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(demoTitle)
                    .font(.headline)
                Spacer()
                // Spacer to balance the skip button
                Text("Skip Demo")
                    .foregroundColor(.clear)
            }
            .padding()

            // Lead-in
            VStack(spacing: 8) {
                Text("Type the verse below")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Letters turn green when correct, red when not. Don't worry about being perfect.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 16)

            // Reuse the full TypingView so the demo *is* the real experience.
            TypingView(
                memorizationText: demoVerse,
                typedText: $demoTypedText,
                difficultyMode: .fullText,
                typingMode: .character,
                settings: demoSettings,
                onComplete: { accuracy, _, _ in
                    demoAccuracy = accuracy
                    // Switch stage on a brief delay so the user sees the
                    // celebration inside TypingView's CompletionView first.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            stage = .demoComplete
                        }
                    }
                    return []  // No badges during onboarding demo
                }
            )
        }
        .onAppear {
            demoStartTime = Date()
        }
    }

    private func startDemo() {
        demoTypedText = ""
        demoAccuracy = 0
        withAnimation {
            stage = .demo
        }
    }

    private func skipDemo() {
        withAnimation {
            stage = .demoComplete
        }
    }

    // MARK: - Demo Complete

    private var demoCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.15))
                    .frame(width: 140, height: 140)

                Image(systemName: "checkmark")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(Theme.primary)
            }

            VStack(spacing: 12) {
                Text(demoAccuracy >= 90 ? "Nicely done!" : "You're off to a great start")
                    .font(.title)
                    .fontWeight(.bold)

                Text("That's exactly how MemorizeIt works. We'll add John 3:16 to your library so you can keep going.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if demoAccuracy > 0 {
                    HStack(spacing: 24) {
                        VStack {
                            Text(String(format: "%.0f%%", demoAccuracy))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primary)
                            Text("Accuracy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: completeOnboarding) {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primary)
                        .cornerRadius(14)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Flow Control

    /// Skip path - jump straight to paywall without seeding demo verse.
    /// We still seed the verse so the user has something to start with.
    private func completeOnboardingSkippingDemo() {
        showPaywall = true
    }

    /// Main path - user finished or skipped the demo and is ready for paywall.
    private func completeOnboarding() {
        showPaywall = true
    }

    private func finishOnboarding() {
        // Seed John 3:16 into SwiftData if the user doesn't already have it,
        // so the empty state isn't actually empty.
        seedDemoVerseIfNeeded()

        withAnimation {
            hasCompletedOnboarding = true
        }
        HapticManager.shared.notification(type: .success)
    }

    private func seedDemoVerseIfNeeded() {
        // Use a UserDefaults flag so we never re-seed (even if the user deletes the verse).
        let key = "didSeedOnboardingVerse"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let item = MemorizeItemModel(
            title: demoTitle,
            categoryName: "Bible Verses",
            memorizeText: demoVerse,
            translation: demoTranslation
        )
        modelContext.insert(item)
        try? modelContext.save()
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.color.opacity(0.15))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(page.color.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: page.icon)
                    .font(.system(size: 60))
                    .foregroundColor(page.color)
            }

            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(hasCompletedOnboarding: .constant(false))
    }
}
