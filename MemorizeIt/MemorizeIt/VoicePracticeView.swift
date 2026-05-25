//
//  VoicePracticeView.swift
//  MemorizeIt
//
//  Voice mode: user recites the verse aloud, we transcribe and score it.
//  Used inside TypingView when typingMode == .voice.
//

import SwiftUI
import AVFoundation

struct VoicePracticeView: View {
    let memorizationText: String
    var onComplete: (Double, Int, Int) -> [Badge]

    @StateObject private var listener = VerseListener()
    @State private var showCompletionAlert: Bool = false
    @State private var finalAccuracy: Double = 0
    @State private var correctWords: Int = 0
    @State private var totalWords: Int = 0
    @State private var newlyEarnedBadges: [Badge] = []
    @State private var hasPromptedAuthorization: Bool = false
    @State private var pulse: Bool = false

    /// Normalized target words (lowercase, punctuation stripped).
    private var targetWords: [String] {
        Self.tokenize(memorizationText)
    }

    /// Normalized transcript words.
    private var transcriptWords: [String] {
        Self.tokenize(listener.transcript)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Verse reference at top
            ScrollView {
                Text(memorizationText)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding()
            }
            .frame(maxHeight: 220)
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            // Live transcript with per-word coloring
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your recitation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !transcriptWords.isEmpty {
                        let matched = Self.matchedWordCount(target: targetWords, transcript: transcriptWords)
                        Text("\(matched) / \(targetWords.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                }

                if transcriptWords.isEmpty {
                    Text(listener.isListening ? "Listening…" : "Tap the mic and start reciting.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .cornerRadius(12)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        transcriptDisplay
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if listener.isFinalizing {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.7)
                                Text("Scoring…")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)

            Spacer()

            // Authorization / error states
            if case .denied(let message) = listener.authorization {
                authorizationDeniedBanner(message: message)
            } else if let error = listener.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            }

            // Mic + finish controls
            HStack(spacing: 24) {
                Button {
                    listener.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 48, height: 48)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }
                .disabled(listener.isListening)

                // Big mic toggle
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(listener.isListening ? Color.red : Theme.primary)
                            .frame(width: 80, height: 80)
                            .scaleEffect(pulse ? 1.08 : 1)
                            .animation(
                                listener.isListening
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                                value: pulse
                            )

                        Image(systemName: listener.isListening ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .disabled(listener.authorization == .unknown && hasPromptedAuthorization)

                Button(action: finish) {
                    Image(systemName: "checkmark")
                        .font(.title3)
                        .foregroundColor(transcriptWords.isEmpty ? .secondary.opacity(0.5) : .green)
                        .frame(width: 48, height: 48)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }
                .disabled(transcriptWords.isEmpty)
            }
            .padding(.bottom, 24)
        }
        .overlay {
            if showCompletionAlert {
                CompletionView(
                    accuracy: finalAccuracy,
                    correctChars: correctWords,
                    totalChars: totalWords,
                    verseText: memorizationText,
                    newlyEarnedBadges: newlyEarnedBadges,
                    onTryAgain: {
                        listener.reset()
                        showCompletionAlert = false
                    },
                    onDone: {
                        showCompletionAlert = false
                    }
                )
                .transition(.opacity)
            }
        }
        .task {
            if !hasPromptedAuthorization {
                hasPromptedAuthorization = true
                await listener.requestAuthorization()
            }
        }
        .onDisappear {
            listener.cancel()
        }
    }

    // MARK: - Transcript Coloring

    private var transcriptDisplay: some View {
        let inLCS = Self.lcsMembership(target: targetWords, transcript: transcriptWords)
        var combined = Text("")
        for i in 0..<transcriptWords.count {
            let color: Color = inLCS[i] ? .green : .red
            combined = combined + Text(transcriptWords[i]).foregroundColor(color) + Text(" ")
        }
        return combined.font(.body)
    }

    // MARK: - Actions

    private func toggleRecording() {
        if listener.isListening {
            Task {
                await listener.stop()
                HapticManager.shared.impact(style: .medium)
            }
        } else {
            startListening()
        }
    }

    private func startListening() {
        guard listener.authorization == .authorized else {
            Task {
                await listener.requestAuthorization()
                if listener.authorization == .authorized {
                    actuallyStart()
                }
            }
            return
        }
        actuallyStart()
    }

    private func actuallyStart() {
        do {
            try listener.start()
            pulse = true
            HapticManager.shared.impact(style: .light)
        } catch {
            listener.errorMessage = error.localizedDescription
        }
    }

    private func finish() {
        pulse = false
        Task {
            // Wait for the recognizer to deliver its final transcript so the
            // tail of the recitation isn't dropped from scoring.
            await listener.stop()

            let target = targetWords
            let said = transcriptWords
            let matched = Self.matchedWordCount(target: target, transcript: said)
            let accuracy = target.isEmpty ? 0 : Double(matched) / Double(target.count) * 100
            finalAccuracy = accuracy
            correctWords = matched
            totalWords = target.count

            newlyEarnedBadges = onComplete(accuracy, matched, target.count)
            showCompletionAlert = true

            if accuracy >= 90 {
                HapticManager.shared.notification(type: .success)
            } else if accuracy >= 70 {
                HapticManager.shared.notification(type: .warning)
            } else {
                HapticManager.shared.notification(type: .error)
            }
        }
    }

    // MARK: - Auth Denied Banner

    private func authorizationDeniedBanner(message: String) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption)
            .foregroundColor(Theme.primary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    /// Lowercase, drop apostrophes (so "God's" tokenizes as "gods", matching
    /// what the recognizer produces), then split on remaining punctuation
    /// and whitespace.
    static func tokenize(_ text: String) -> [String] {
        var lowered = text.lowercased()
        // Apostrophes are dropped (not treated as splitters) so contractions
        // like "I'm" / "God's" become one token, matching transcript form.
        for apostrophe in ["'", "\u{2018}", "\u{2019}", "\u{02BC}"] {
            lowered = lowered.replacingOccurrences(of: apostrophe, with: "")
        }
        let cleaned = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.punctuationCharacters.contains(scalar) ? " " : Character(scalar)
        }
        return String(cleaned)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    /// Returns a Bool per transcript word indicating membership in the
    /// longest common subsequence with the target. This is robust against
    /// the user dropping or adding a word — only the actually-misspoken
    /// words turn red, instead of the whole tail of the verse.
    static func lcsMembership(target: [String], transcript: [String]) -> [Bool] {
        let m = target.count
        let n = transcript.count
        guard m > 0, n > 0 else { return Array(repeating: false, count: n) }

        // dp[i][j] = LCS length of target[..<i] and transcript[..<j]
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 0..<m {
            for j in 0..<n where target[i] == transcript[j] {
                dp[i + 1][j + 1] = dp[i][j] + 1
            }
            for j in 0..<n where target[i] != transcript[j] {
                dp[i + 1][j + 1] = max(dp[i][j + 1], dp[i + 1][j])
            }
        }

        // Backtrack to flag which transcript indices participate in the LCS.
        var inLCS = Array(repeating: false, count: n)
        var i = m, j = n
        while i > 0 && j > 0 {
            if target[i - 1] == transcript[j - 1] {
                inLCS[j - 1] = true
                i -= 1
                j -= 1
            } else if dp[i - 1][j] >= dp[i][j - 1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return inLCS
    }

    /// Number of target words recited correctly (regardless of order/extras).
    /// = length of LCS between target and transcript.
    static func matchedWordCount(target: [String], transcript: [String]) -> Int {
        lcsMembership(target: target, transcript: transcript).reduce(0) { $0 + ($1 ? 1 : 0) }
    }
}
