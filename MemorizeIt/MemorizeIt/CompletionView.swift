//
//  CompletionView.swift
//  MemorizeIt
//
//  Created by Brevin Blalock
//

import SwiftUI

struct CompletionView: View {
    let accuracy: Double
    let correctChars: Int
    let totalChars: Int
    var verseText: String = ""
    var newlyEarnedBadges: [Badge] = []
    let onTryAgain: () -> Void
    let onDone: () -> Void
    /// When non-nil, replaces "Done" with "Next Verse" to chain queued sessions.
    var onNextVerse: (() -> Void)? = nil

    @State private var showConfetti = false
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var shareImage: ShareableImage?

    var completionMessage: String {
        if accuracy == 100 {
            return "Perfect!"
        } else if accuracy >= 95 {
            return "Excellent!"
        } else if accuracy >= 90 {
            return "Great Job!"
        } else if accuracy >= 80 {
            return "Good Work!"
        } else if accuracy >= 70 {
            return "Nice Try!"
        } else {
            return "Keep Practicing!"
        }
    }

    var completionEmoji: String {
        if accuracy == 100 {
            return "🎉"
        } else if accuracy >= 95 {
            return "🌟"
        } else if accuracy >= 90 {
            return "👏"
        } else if accuracy >= 80 {
            return "👍"
        } else if accuracy >= 70 {
            return "💪"
        } else {
            return "📖"
        }
    }

    var completionColor: Color {
        if accuracy >= 90 {
            return .green
        } else if accuracy >= 70 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Prevent dismissal on background tap
                }

            // Confetti
            if showConfetti && accuracy >= 90 {
                ConfettiView()
            }

            // Card
            VStack(spacing: 24) {
                // Emoji
                Text(completionEmoji)
                    .font(.system(size: 80))
                    .scaleEffect(scale)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: scale)

                // Title
                Text(completionMessage)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)

                // Accuracy Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: accuracy / 100)
                        .stroke(completionColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.3), value: accuracy)

                    VStack(spacing: 4) {
                        Text(String(format: "%.1f%%", accuracy))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(completionColor)

                        Text("Accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)

                // Stats
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("\(correctChars)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.green)
                        Text("Correct")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 4) {
                        Text("\(totalChars - correctChars)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.red)
                        Text("Errors")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)

                // Newly earned badges (if any)
                if !newlyEarnedBadges.isEmpty {
                    Divider()
                        .padding(.horizontal)

                    VStack(spacing: 8) {
                        Text(newlyEarnedBadges.count == 1 ? "Badge Earned!" : "\(newlyEarnedBadges.count) Badges Earned!")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        HStack(spacing: 16) {
                            ForEach(newlyEarnedBadges) { badge in
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(badge.color.opacity(0.18))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: badge.icon)
                                            .font(.system(size: 22))
                                            .foregroundColor(badge.color)
                                    }
                                    Text(badge.title)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                }

                Divider()
                    .padding(.horizontal)

                // Buttons - primary action depends on whether we're in a queue
                VStack(spacing: 12) {
                    if let onNextVerse {
                        // Queue mode: emphasize Next Verse
                        Button(action: onNextVerse) {
                            HStack {
                                Text("Next Verse")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        HStack(spacing: 12) {
                            Button(action: onTryAgain) {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Try Again")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundColor(Theme.primary)
                                .background(Theme.primary.opacity(0.1))
                                .cornerRadius(12)
                            }

                            Button(action: onDone) {
                                Text("End Session")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        // Single-verse mode: Try Again is primary
                        Button(action: onTryAgain) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Try Again")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Theme.primary)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        HStack(spacing: 12) {
                            // Share button (only if we have the verse to render)
                            if !verseText.isEmpty && accuracy >= 70 {
                                Button(action: prepareShareImage) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Share")
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(Theme.primary)
                                    .background(Theme.primary.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }

                            Button(action: onDone) {
                                Text("Done")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .foregroundColor(Theme.primary)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(32)
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 32)
            .opacity(opacity)
            .scaleEffect(scale)
        }
        .onAppear {
            // Haptic feedback based on performance
            if accuracy == 100 {
                HapticManager.shared.notification(type: .success)
            } else if accuracy >= 90 {
                HapticManager.shared.notification(type: .success)
            } else if accuracy >= 70 {
                HapticManager.shared.notification(type: .warning)
            } else {
                HapticManager.shared.notification(type: .error)
            }

            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            if accuracy >= 90 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                }
            }

            // Request review after great sessions
            ReviewManager.shared.recordGreatSession(accuracy: accuracy)
        }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image, item.caption])
        }
    }

    @MainActor
    private func prepareShareImage() {
        let card = ShareCard(verseText: verseText, accuracy: accuracy)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let ui = renderer.uiImage {
            shareImage = ShareableImage(
                image: ui,
                caption: "I just memorized this with MemorizeIt — \(Int(accuracy))% accuracy!"
            )
        }
        HapticManager.shared.impact(style: .medium)
    }
}

// MARK: - Share Components

/// Wraps the rendered image so SwiftUI's `sheet(item:)` can present it.
struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
    let caption: String
}

/// The actual card that gets snapshotted to share. Designed to look good on
/// Instagram Stories / Messages.
struct ShareCard: View {
    let verseText: String
    let accuracy: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.white)
                Text("MemorizeIt")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f%%", accuracy))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Spacer()

            Text("\u{201C}" + verseText + "\u{201D}")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(8)

            Spacer()

            Text("Memorized with MemorizeIt")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(32)
        .frame(width: 360, height: 480)
        .background(
            LinearGradient(
                colors: [Theme.primary, Theme.primaryDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

/// UIKit bridge for sharing arbitrary items via UIActivityViewController.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            ForEach(confettiPieces) { piece in
                ConfettiShape()
                    .fill(piece.color)
                    .frame(width: piece.size, height: piece.size)
                    .position(piece.position)
                    .rotationEffect(piece.rotation)
                    .opacity(piece.opacity)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            generateConfetti()
        }
    }

    func generateConfetti() {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]

        for _ in 0..<50 {
            let piece = ConfettiPiece(
                position: CGPoint(x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                                y: -50),
                color: colors.randomElement() ?? .blue,
                size: CGFloat.random(in: 8...15),
                rotation: .degrees(Double.random(in: 0...360)),
                opacity: 1.0
            )
            confettiPieces.append(piece)

            animateConfetti(piece: piece)
        }
    }

    func animateConfetti(piece: ConfettiPiece) {
        withAnimation(.easeIn(duration: Double.random(in: 2...4))) {
            if let index = confettiPieces.firstIndex(where: { $0.id == piece.id }) {
                confettiPieces[index].position.y = UIScreen.main.bounds.height + 100
                confettiPieces[index].opacity = 0
            }
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var position: CGPoint
    let color: Color
    let size: CGFloat
    let rotation: Angle
    var opacity: Double
}

struct ConfettiShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        return path
    }
}

#Preview {
    CompletionView(
        accuracy: 95.5,
        correctChars: 135,
        totalChars: 142,
        onTryAgain: {},
        onDone: {}
    )
}
