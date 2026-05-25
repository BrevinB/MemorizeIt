import SwiftUI
import SwiftData
import AVFoundation
import AudioToolbox

enum DifficultyMode: String, CaseIterable, Identifiable {
    case fullText = "Full Text"
    case hiddenWords = "Hidden Words"
    case firstLetter = "First Letter"
    case fillInTheBlank = "Fill in the Blank"
    case blankCanvas = "Blank Canvas"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .fullText:
            return "See all words while typing"
        case .hiddenWords:
            return "First letter + word length shown"
        case .firstLetter:
            return "Only first letters are visible"
        case .fillInTheBlank:
            return "Key words are hidden; type only those"
        case .blankCanvas:
            return "No hints shown"
        }
    }
}

enum TypingMode: String, CaseIterable {
    case character = "Character"
    case word = "Word"
    case voice = "Voice"

    var description: String {
        switch self {
        case .character:
            return "Type character by character"
        case .word:
            return "Type word by word"
        case .voice:
            return "Recite the verse out loud"
        }
    }

    /// Voice mode is a premium feature.
    var requiresPremium: Bool {
        self == .voice
    }
}

// MARK: - Typing Settings
struct TypingSettings {
    var caseInsensitive: Bool = false
    var ignorePunctuation: Bool = false
    var audioFeedback: Bool = true
    var hapticFeedback: Bool = true

    static func load() -> TypingSettings {
        var settings = TypingSettings()
        settings.caseInsensitive = UserDefaults.standard.bool(forKey: "typing_caseInsensitive")
        settings.ignorePunctuation = UserDefaults.standard.bool(forKey: "typing_ignorePunctuation")
        settings.audioFeedback = UserDefaults.standard.object(forKey: "typing_audioFeedback") as? Bool ?? true
        settings.hapticFeedback = UserDefaults.standard.object(forKey: "typing_hapticFeedback") as? Bool ?? true
        return settings
    }

    func save() {
        UserDefaults.standard.set(caseInsensitive, forKey: "typing_caseInsensitive")
        UserDefaults.standard.set(ignorePunctuation, forKey: "typing_ignorePunctuation")
        UserDefaults.standard.set(audioFeedback, forKey: "typing_audioFeedback")
        UserDefaults.standard.set(hapticFeedback, forKey: "typing_hapticFeedback")
    }
}

struct MemorizeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query private var appStats: [AppStats]
    @StateObject private var purchaseManager = PurchaseManager.shared

    let item: MemorizeItemModel
    /// Optional Practice-Now queue context: (current index, total) – when set,
    /// MemorizeView shows a queue badge and CompletionView shows "Next Verse".
    var queueProgress: (current: Int, total: Int)? = nil
    /// Called when the user finishes a queued verse and wants to advance.
    var queueAdvance: (() -> Void)? = nil

    @State private var typedText: String = ""
    @State private var selectedMode: DifficultyMode = .fullText
    @State private var typingMode: TypingMode = .character
    @State private var startTime: Date = Date()
    @State private var showPaywall: Bool = false
    @State private var showSettings: Bool = false
    @State private var settings: TypingSettings = TypingSettings.load()
    @State private var previewLockedMode: DifficultyMode?

    /// Difficulty modes available based on subscription status
    private var availableModes: [DifficultyMode] {
        if purchaseManager.isPremium {
            return DifficultyMode.allCases
        } else {
            return [.fullText] // Free users only get Full Text
        }
    }

    var stats: AppStats {
        if let existingStats = appStats.first {
            return existingStats
        } else {
            let newStats = AppStats()
            modelContext.insert(newStats)
            return newStats
        }
    }

    // MARK: - iPhone Layout
    private var iPhonePracticeLayout: some View {
        VStack(spacing: 0) {
            TypingView(
                memorizationText: item.memorizeText,
                typedText: $typedText,
                difficultyMode: selectedMode,
                typingMode: typingMode,
                settings: settings,
                onComplete: { accuracy, correctChars, totalChars in
                    return savePracticeSession(accuracy: accuracy, correctChars: correctChars, totalChars: totalChars)
                },
                onNextVerse: queueAdvance
            )
        }
    }

    // MARK: - iPad Layout
    private var iPadPracticeLayout: some View {
        HStack(spacing: 0) {
            // Left panel - Reference and info
            VStack(alignment: .leading, spacing: 16) {
                // Item info header
                HStack {
                    ZStack {
                        Circle()
                            .fill(Theme.categoryColor(for: item.categoryName).opacity(0.2))
                            .frame(width: 50, height: 50)
                        Image(systemName: Theme.categoryIcon(for: item.categoryName))
                            .font(.title2)
                            .foregroundColor(Theme.categoryColor(for: item.categoryName))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        if let translation = item.translation {
                            Text(translation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Theme.primary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)

                // Mode indicator
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Mode: \(selectedMode.rawValue)")
                            .font(.headline)
                        Spacer()
                        Text(typingMode.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .cornerRadius(6)
                    }

                    Text(selectedMode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Divider()

                    // Stats summary
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(item.practiceCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.primary)
                            Text("Sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text(String(format: "%.0f%%", item.bestAccuracy))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            Text("Best")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        VStack {
                            Text(String(format: "%.0f%%", item.averageAccuracy))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            Text("Average")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(16)

                // Reference text for Full Text mode
                if selectedMode == .fullText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reference")
                            .font(.headline)

                        ScrollView {
                            Text(item.memorizeText)
                                .font(.body)
                                .lineSpacing(6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .cornerRadius(16)
                } else {
                    Spacer()
                }
            }
            .frame(width: 320)
            .padding()

            Divider()

            // Right panel - Typing area
            TypingView(
                memorizationText: item.memorizeText,
                typedText: $typedText,
                difficultyMode: selectedMode,
                typingMode: typingMode,
                settings: settings,
                onComplete: { accuracy, correctChars, totalChars in
                    return savePracticeSession(accuracy: accuracy, correctChars: correctChars, totalChars: totalChars)
                },
                onNextVerse: queueAdvance
            )
            .frame(maxWidth: .infinity)
        }
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                // iPad: Split layout with reference panel on left
                iPadPracticeLayout
            } else {
                // iPhone: Standard layout
                iPhonePracticeLayout
            }
        }
        .navigationTitle(item.title)
        .toolbar {
            if let progress = queueProgress {
                ToolbarItem(placement: .principal) {
                    Text("\(progress.current) of \(progress.total)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Theme.primary)
                        )
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Listen button - reads the verse aloud (free for all users)
                    ListenButton(text: item.memorizeText)

                    // Settings button
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }

                    // Difficulty menu
                    Menu {
                        // Difficulty modes
                        Section("Difficulty") {
                            Picker("Difficulty", selection: $selectedMode) {
                                ForEach(availableModes, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }

                            // Locked modes - tapping shows a live preview of
                            // what that mode looks like before paywall.
                            if !purchaseManager.isPremium {
                                ForEach(
                                    DifficultyMode.allCases.filter { $0 != .fullText },
                                    id: \.self
                                ) { mode in
                                    Button {
                                        previewLockedMode = mode
                                    } label: {
                                        Label(mode.rawValue, systemImage: "lock.fill")
                                    }
                                }
                            }
                        }

                        Section("Typing Mode") {
                            ForEach(TypingMode.allCases, id: \.self) { mode in
                                Button {
                                    if mode.requiresPremium && !purchaseManager.isPremium {
                                        showPaywall = true
                                    } else {
                                        typingMode = mode
                                    }
                                } label: {
                                    HStack {
                                        Text(mode.rawValue)
                                        if mode == typingMode {
                                            Image(systemName: "checkmark")
                                        }
                                        Spacer()
                                        if mode.requiresPremium && !purchaseManager.isPremium {
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                        if !purchaseManager.isPremium {
                            Divider()

                            Button {
                                showPaywall = true
                            } label: {
                                Label("Unlock All Modes", systemImage: "crown.fill")
                            }
                        }
                    } label: {
                        Label("Options", systemImage: "slider.horizontal.3")
                    }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showSettings) {
            TypingSettingsView(settings: $settings)
        }
        .sheet(item: $previewLockedMode) { mode in
            DifficultyModePreviewSheet(
                mode: mode,
                verseText: item.memorizeText,
                onUnlock: {
                    previewLockedMode = nil
                    showPaywall = true
                }
            )
        }
        .onChange(of: selectedMode) { oldValue, newValue in
            typedText = ""
            startTime = Date()
        }
        .onChange(of: typingMode) { oldValue, newValue in
            typedText = ""
            startTime = Date()
        }
        .onAppear {
            startTime = Date()
        }
    }

    @discardableResult
    private func savePracticeSession(accuracy: Double, correctChars: Int, totalChars: Int) -> [Badge] {
        let timeSpent = Date().timeIntervalSince(startTime)

        let session = PracticeSession(
            accuracy: accuracy,
            correctChars: correctChars,
            totalChars: totalChars,
            difficultyMode: selectedMode.rawValue,
            timeSpent: timeSpent
        )
        session.item = item
        modelContext.insert(session)

        // Update item's last practiced date
        item.lastPracticedAt = Date()

        // Update spaced repetition schedule based on accuracy
        item.updateSpacedRepetition(accuracy: accuracy)

        // Update app stats
        stats.updateStreak()
        stats.totalPracticeSessions += 1
        stats.totalTimeSpent += timeSpent

        // Bump weekly progress (resets automatically on ISO week rollover)
        WeeklyGoalStore.shared.recordSession()

        // Check for streak milestone (for review prompt)
        ReviewManager.shared.checkStreakMilestone(currentStreak: stats.currentStreak)

        // Evaluate achievement badges. Returned list = newly earned this session.
        let verseCount = (try? modelContext.fetchCount(FetchDescriptor<MemorizeItemModel>())) ?? 0
        let newBadges = BadgeManager.shared.evaluate(
            currentStreak: stats.currentStreak,
            totalSessions: stats.totalPracticeSessions,
            verseCount: verseCount,
            latestAccuracy: accuracy
        )

        do {
            try modelContext.save()
        } catch {
            print("Error saving practice session: \(error)")
        }

        return newBadges
    }
}

// MARK: - Typing Settings View
struct TypingSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: TypingSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Comparison Options") {
                    Toggle(isOn: $settings.caseInsensitive) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ignore Case")
                            Text("Treat uppercase and lowercase as the same")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $settings.ignorePunctuation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Ignore Punctuation")
                            Text("Skip commas, periods, apostrophes, etc.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Feedback") {
                    Toggle(isOn: $settings.audioFeedback) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sound Effects")
                            Text("Play sounds on errors and completion")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $settings.hapticFeedback) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Haptic Feedback")
                            Text("Vibrate on errors and completion")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Typing Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        settings.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Audio Feedback Manager
class TypingAudioManager {
    static let shared = TypingAudioManager()

    private init() {}

    func playError() {
        // Gentle "pop" sound for errors
        AudioServicesPlaySystemSound(1519)
    }

    func playComplete() {
        // Cheerful completion sound
        AudioServicesPlaySystemSound(1407)
    }
}

// MARK: - Typing View
struct TypingView: View {
    var memorizationText: String
    @Binding var typedText: String
    var difficultyMode: DifficultyMode
    var typingMode: TypingMode
    var settings: TypingSettings
    /// Called when the user finishes a session. Caller persists the session and
    /// returns any badges newly earned, which CompletionView surfaces.
    var onComplete: (Double, Int, Int) -> [Badge]
    /// Optional - when set, CompletionView shows a "Next Verse" button that
    /// invokes this callback. Used by PracticeQueueView to chain sessions.
    var onNextVerse: (() -> Void)? = nil

    @State private var showCompletionAlert = false
    @State private var finalAccuracy: Double = 0
    @State private var newlyEarnedBadges: [Badge] = []
    @State private var showHint = false
    @State private var hintText = ""
    @State private var lastErrorIndex: Int? = nil
    @State private var showErrorPopover = false
    @State private var errorInfo: (expected: String, typed: String) = ("", "")
    @State private var previousTypedCount = 0
    @FocusState private var isTextFieldFocused: Bool

    // For word mode
    @State private var currentWordInput: String = ""
    @State private var completedWords: [String] = []

    private let audioManager = TypingAudioManager.shared

    // MARK: - Text Processing

    // Characters to ignore when punctuation mode is enabled
    private let punctuationCharacters = CharacterSet.punctuationCharacters

    /// Normalize text for comparison
    func normalizeText(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if settings.ignorePunctuation {
            result = result.unicodeScalars.filter { !punctuationCharacters.contains($0) }.map { String($0) }.joined()
        }

        return result
    }

    /// Compare two characters based on settings
    func charactersMatch(_ typed: Character, _ expected: Character) -> Bool {
        var t = typed
        var e = expected

        // Handle whitespace
        if t.isWhitespace && e.isWhitespace {
            return true
        }

        // Case insensitive
        if settings.caseInsensitive {
            t = Character(t.lowercased())
            e = Character(e.lowercased())
        }

        return t == e
    }

    // MARK: - Computed Properties

    var processedMemorizationText: String {
        normalizeText(memorizationText)
    }

    var processedTypedText: String {
        if typingMode == .word {
            return completedWords.joined(separator: " ") + (completedWords.isEmpty ? "" : " ") + currentWordInput
        }
        return normalizeText(typedText)
    }

    var words: [String] {
        processedMemorizationText.components(separatedBy: " ").filter { !$0.isEmpty }
    }

    var currentWordIndex: Int {
        completedWords.count
    }

    var currentExpectedWord: String? {
        guard currentWordIndex < words.count else { return nil }
        return words[currentWordIndex]
    }

    var correctChars: Int {
        let typed = processedTypedText
        let target = processedMemorizationText

        var count = 0
        let minLength = min(typed.count, target.count)

        for i in 0..<minLength {
            let typedIndex = typed.index(typed.startIndex, offsetBy: i)
            let targetIndex = target.index(target.startIndex, offsetBy: i)

            if charactersMatch(typed[typedIndex], target[targetIndex]) {
                count += 1
            }
        }
        return count
    }

    var totalChars: Int {
        processedMemorizationText.count
    }

    var accuracy: Double {
        guard totalChars > 0 else { return 0 }
        return Double(correctChars) / Double(totalChars) * 100
    }

    var isComplete: Bool {
        if typingMode == .word {
            return completedWords.count >= words.count
        }
        return processedTypedText.count >= totalChars
    }

    var currentPosition: Int {
        processedTypedText.count
    }

    // MARK: - Body

    @ViewBuilder
    var body: some View {
        if typingMode == .voice {
            // Voice mode owns its own UI - the typing-centric chrome
            // (stats header, hint bar, keyboard area, action bar) doesn't apply.
            VoicePracticeView(memorizationText: memorizationText, onComplete: onComplete)
        } else {
            typingBody
        }
    }

    private var typingBody: some View {
        VStack(spacing: 0) {
            // Stats header
            statsHeader

            Divider()

            // Hint bar (if showing)
            if showHint {
                hintBar
            }

            // Typing area based on mode
            if typingMode == .word {
                wordModeTypingArea
            } else {
                characterModeTypingArea
            }

            // Action bar
            actionBar

            Spacer()
        }
        .overlay {
            if showCompletionAlert {
                CompletionView(
                    accuracy: finalAccuracy,
                    correctChars: correctChars,
                    totalChars: totalChars,
                    verseText: memorizationText,
                    newlyEarnedBadges: newlyEarnedBadges,
                    onTryAgain: {
                        resetTyping()
                        showCompletionAlert = false
                    },
                    onDone: {
                        showCompletionAlert = false
                    },
                    onNextVerse: onNextVerse.map { advance in
                        { showCompletionAlert = false; advance() }
                    }
                )
                .transition(.opacity)
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }

    // MARK: - Stats Header

    var statsHeader: some View {
        VStack(spacing: 16) {
            // Progress bar
            VStack(spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)

                    Spacer()

                    if typingMode == .word {
                        Text("\(completedWords.count) / \(words.count) words")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    } else {
                        Text("\(currentPosition) / \(totalChars)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.primary, Theme.primaryLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(0, geometry.size.width * progressRatio),
                                height: 8
                            )
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPosition)
                    }
                }
                .frame(height: 8)
            }

            // Accuracy display
            HStack(spacing: 20) {
                // Accuracy circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: min(accuracy / 100, 1.0))
                        .stroke(
                            accuracyColor,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: accuracy)

                    Text(String(format: "%.0f%%", accuracy))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(accuracyColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Correct: \(correctChars)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        Text("Errors: \(max(0, currentPosition - correctChars))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Error info button (if there was a recent error)
                if lastErrorIndex != nil {
                    Button {
                        showErrorPopover.toggle()
                    } label: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.title3)
                    }
                    .popover(isPresented: $showErrorPopover) {
                        errorPopoverContent
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(uiColor: .systemBackground), Color(uiColor: .secondarySystemBackground).opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    var progressRatio: Double {
        if typingMode == .word {
            guard words.count > 0 else { return 0 }
            return Double(completedWords.count) / Double(words.count)
        } else {
            guard totalChars > 0 else { return 0 }
            return Double(currentPosition) / Double(totalChars)
        }
    }

    var accuracyColor: Color {
        if accuracy >= 90 { return .green }
        if accuracy >= 70 { return .orange }
        return .red
    }

    // MARK: - Hint Bar

    var hintBar: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)

            Text("Next: \"\(hintText)\"")
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()

            Button {
                showHint = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.1))
    }

    // MARK: - Character Mode Typing Area

    var characterModeTypingArea: some View {
        ZStack(alignment: .topLeading) {
            // Transparent TextEditor for typing - with hidden cursor
            TextEditor(text: $typedText)
                .font(.system(size: 18))
                .foregroundColor(.clear)
                .background(Color.clear)
                .padding(8)
                .scrollContentBackground(.hidden)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .focused($isTextFieldFocused)
                .tint(.clear) // Hide the cursor
                .onChange(of: typedText) { oldValue, newValue in
                    handleCharacterInput(oldValue: oldValue, newValue: newValue)
                }

            // The background text with color-coding and cursor
            buildColoredText()
                .font(.system(size: 18))
                .padding(12)
                .allowsHitTesting(false)
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Word Mode Typing Area

    var wordModeTypingArea: some View {
        VStack(spacing: 16) {
            // Display completed and upcoming words
            ScrollView {
                FlowLayout(spacing: 8) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        wordBubble(word: word, index: index)
                    }
                }
                .padding()
            }

            // Current word input
            if let expectedWord = currentExpectedWord {
                VStack(spacing: 8) {
                    Text("Type this word:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    switch difficultyMode {
                    case .fullText:
                        Text(expectedWord)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    case .hiddenWords:
                        // Show first letter + underscores to reveal word length
                        Text(String(expectedWord.prefix(1)) + String(repeating: "_", count: max(0, expectedWord.count - 1)))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    case .firstLetter:
                        // Show only the first letter – no length hint
                        Text(String(expectedWord.prefix(1)))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    case .fillInTheBlank:
                        // Key words are blanked; non-key words are auto-advanced
                        // so by the time we reach here the word is always a key word.
                        Text(String(repeating: "_", count: expectedWord.count))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    case .blankCanvas:
                        Text(String(repeating: "_", count: expectedWord.count))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    TextField("Type here...", text: $currentWordInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            submitWord()
                        }
                        .padding(.horizontal, 40)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
        .onAppear {
            // Auto-advance leading non-key words when entering Fill-in-the-Blank mode
            advanceNonKeyWordsIfNeeded()
        }
        .onChange(of: difficultyMode) { _, _ in
            advanceNonKeyWordsIfNeeded()
        }
    }

    func wordBubble(word: String, index: Int) -> some View {
        let isCompleted = index < completedWords.count
        let isCurrent = index == currentWordIndex
        let isCorrect = isCompleted && wordsMatch(completedWords[index], word)

        let displayText: String
        if isCompleted {
            displayText = completedWords[index]
        } else {
            switch difficultyMode {
            case .fullText:
                displayText = word
            case .hiddenWords:
                // First letter + underscores to reveal word length
                displayText = String(word.prefix(1)) + String(repeating: "_", count: max(0, word.count - 1))
            case .firstLetter:
                // Only the first letter – no length information
                displayText = String(word.prefix(1))
            case .fillInTheBlank:
                // Non-key words show their text (context aid); key words are blanked
                displayText = isKeyWord(word) ? String(repeating: "_", count: word.count) : word
            case .blankCanvas:
                displayText = String(repeating: "_", count: word.count)
            }
        }

        return Text(displayText)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(bubbleColor(isCompleted: isCompleted, isCurrent: isCurrent, isCorrect: isCorrect))
            )
            .foregroundColor(bubbleTextColor(isCompleted: isCompleted, isCurrent: isCurrent, isCorrect: isCorrect))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isCurrent ? Theme.primary : Color.clear, lineWidth: 2)
            )
    }

    func bubbleColor(isCompleted: Bool, isCurrent: Bool, isCorrect: Bool) -> Color {
        if isCompleted {
            return isCorrect ? Color.green.opacity(0.2) : Color.red.opacity(0.2)
        }
        if isCurrent {
            return Theme.primary.opacity(0.1)
        }
        return Color.gray.opacity(0.1)
    }

    func bubbleTextColor(isCompleted: Bool, isCurrent: Bool, isCorrect: Bool) -> Color {
        if isCompleted {
            return isCorrect ? .green : .red
        }
        if isCurrent {
            return Theme.primary
        }
        return .secondary
    }

    func wordsMatch(_ typed: String, _ expected: String) -> Bool {
        var t = typed
        var e = expected

        if settings.caseInsensitive {
            t = t.lowercased()
            e = e.lowercased()
        }

        if settings.ignorePunctuation {
            t = t.unicodeScalars.filter { !punctuationCharacters.contains($0) }.map { String($0) }.joined()
            e = e.unicodeScalars.filter { !punctuationCharacters.contains($0) }.map { String($0) }.joined()
        }

        return t == e
    }

    func submitWord() {
        guard let expectedWord = currentExpectedWord else { return }

        let isCorrect = wordsMatch(currentWordInput, expectedWord)

        completedWords.append(currentWordInput)
        currentWordInput = ""

        // In Fill-in-the-Blank mode skip over non-key words automatically so
        // the user only has to type the meaningful vocabulary.
        advanceNonKeyWordsIfNeeded()

        // Feedback on errors only (iOS keyboard handles correct input feedback)
        if !isCorrect {
            if settings.audioFeedback { audioManager.playError() }
            if settings.hapticFeedback { HapticManager.shared.notification(type: .error) }
            errorInfo = (expected: expectedWord, typed: completedWords.last ?? "")
            lastErrorIndex = completedWords.count - 1
        }

        // Check completion
        if completedWords.count >= words.count {
            finalAccuracy = accuracy
            isTextFieldFocused = false // Dismiss keyboard
            newlyEarnedBadges = onComplete(accuracy, correctChars, totalChars)
            showCompletionAlert = true
            if settings.audioFeedback { audioManager.playComplete() }
            if settings.hapticFeedback { HapticManager.shared.notification(type: .success) }
        }
    }

    // MARK: - Action Bar

    var actionBar: some View {
        HStack(spacing: 20) {
            // Hint button
            Button {
                showNextHint()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "lightbulb")
                        .font(.title3)
                    Text("Hint")
                        .font(.caption2)
                }
                .foregroundColor(Theme.primary)
            }

            Spacer()

            // Keyboard dismiss button
            Button {
                isTextFieldFocused = false
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.title3)
                    Text("Hide")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }

            Spacer()

            // Reset button
            Button {
                resetTyping()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3)
                    Text("Reset")
                        .font(.caption2)
                }
                .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Error Popover

    var errorPopoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Error")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Expected:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(errorInfo.expected)
                        .font(.body)
                        .foregroundColor(.green)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("You typed:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(errorInfo.typed)
                        .font(.body)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .frame(minWidth: 200)
    }

    // MARK: - Helper Functions

    func handleCharacterInput(oldValue: String, newValue: String) {
        let normalizedNew = normalizeText(newValue)
        let normalizedOld = normalizeText(oldValue)
        let target = processedMemorizationText

        // Prevent typing more than target length
        if normalizedNew.count > target.count {
            typedText = oldValue
            return
        }

        // Check for new character typed
        if normalizedNew.count > normalizedOld.count {
            let newCharIndex = normalizedNew.count - 1
            if newCharIndex < target.count {
                let typedIndex = normalizedNew.index(normalizedNew.startIndex, offsetBy: newCharIndex)
                let targetIndex = target.index(target.startIndex, offsetBy: newCharIndex)

                let isCorrect = charactersMatch(normalizedNew[typedIndex], target[targetIndex])

                if !isCorrect {
                    if settings.audioFeedback { audioManager.playError() }
                    if settings.hapticFeedback { HapticManager.shared.notification(type: .error) }
                    errorInfo = (expected: String(target[targetIndex]), typed: String(normalizedNew[typedIndex]))
                    lastErrorIndex = newCharIndex
                }
            }
        }

        // Check completion
        if normalizedNew.count >= target.count && !showCompletionAlert {
            finalAccuracy = accuracy
            isTextFieldFocused = false // Dismiss keyboard
            newlyEarnedBadges = onComplete(accuracy, correctChars, target.count)
            showCompletionAlert = true
            if settings.audioFeedback { audioManager.playComplete() }
            if settings.hapticFeedback { HapticManager.shared.notification(type: .success) }
        }

        previousTypedCount = normalizedNew.count
    }

    func showNextHint() {
        let target = processedMemorizationText
        let currentPos = processedTypedText.count

        if typingMode == .word {
            if let word = currentExpectedWord {
                hintText = word
            }
        } else {
            // Show next 5 characters
            let endPos = min(currentPos + 5, target.count)
            if currentPos < target.count {
                let startIndex = target.index(target.startIndex, offsetBy: currentPos)
                let endIndex = target.index(target.startIndex, offsetBy: endPos)
                hintText = String(target[startIndex..<endIndex])
            }
        }

        showHint = true

        // Auto-hide after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showHint = false
        }
    }

    func resetTyping() {
        typedText = ""
        completedWords = []
        currentWordInput = ""
        lastErrorIndex = nil
        showHint = false
        previousTypedCount = 0
        isTextFieldFocused = true
        // Immediately skip non-key words so FITB word mode starts on a key word
        advanceNonKeyWordsIfNeeded()
    }

    // Returns true if the word is a "key word" that should be hidden in Fill-in-the-Blank mode.
    // Words with more than 4 characters (after stripping punctuation) are considered key words.
    func isKeyWord(_ word: String) -> Bool {
        let clean = word.unicodeScalars
            .filter { !punctuationCharacters.contains($0) }
            .map { String($0) }
            .joined()
        return clean.count > 4
    }

    // Returns an array where each index corresponds to a character in `target` and
    // indicates whether that character belongs to a key word (true) or not (false).
    // Space/newline characters are always false.
    func buildKeyWordMask(for target: String) -> [Bool] {
        var mask = Array(repeating: false, count: target.count)
        var wordStartIdx: Int? = nil

        for (i, char) in target.enumerated() {
            if char == " " || char == "\n" {
                if let start = wordStartIdx {
                    let startStrIdx = target.index(target.startIndex, offsetBy: start)
                    let endStrIdx = target.index(target.startIndex, offsetBy: i)
                    let word = String(target[startStrIdx..<endStrIdx])
                    if isKeyWord(word) {
                        for j in start..<i { mask[j] = true }
                    }
                    wordStartIdx = nil
                }
            } else if wordStartIdx == nil {
                wordStartIdx = i
            }
        }
        // Handle the last word in the string
        if let start = wordStartIdx {
            let startStrIdx = target.index(target.startIndex, offsetBy: start)
            let word = String(target[startStrIdx...])
            if isKeyWord(word) {
                for j in start..<target.count { mask[j] = true }
            }
        }
        return mask
    }

    // In Fill-in-the-Blank word mode, automatically accept all non-key words so
    // the user only has to type the meaningful vocabulary words.
    func advanceNonKeyWordsIfNeeded() {
        guard difficultyMode == .fillInTheBlank else { return }
        while currentWordIndex < words.count && !isKeyWord(words[currentWordIndex]) {
            completedWords.append(words[currentWordIndex])
        }
    }

    // Helper to check if a character is at the start of a word
    func isWordStart(at index: Int, in text: String) -> Bool {
        if index == 0 { return true }
        let prevIndex = text.index(text.startIndex, offsetBy: index - 1)
        let prevChar = text[prevIndex]
        return prevChar == " " || prevChar == "\n"
    }

    // Build colored text with cursor indicator
    func buildColoredText() -> Text {
        var resultText = Text("")
        let typed = processedTypedText
        let target = processedMemorizationText

        // Precompute keyword mask once for Fill-in-the-Blank so we don't repeat
        // the word-scanning work inside the per-character loop.
        let keyWordMask: [Bool] = difficultyMode == .fillInTheBlank
            ? buildKeyWordMask(for: target)
            : []

        for index in 0..<target.count {
            let targetIndex = target.index(target.startIndex, offsetBy: index)
            let correctChar = target[targetIndex]
            let hasBeenTyped = index < typed.count
            let isCursorPosition = index == typed.count

            if hasBeenTyped {
                let typedIndex = typed.index(typed.startIndex, offsetBy: index)
                let typedChar = typed[typedIndex]
                let isCorrect = charactersMatch(typedChar, correctChar)

                resultText = resultText + Text(String(correctChar))
                    .foregroundColor(isCorrect ? .green : .red)
                    .fontWeight(isCorrect ? .regular : .bold)
            } else {
                // Add cursor indicator at current position
                if isCursorPosition {
                    resultText = resultText + Text("|")
                        .foregroundColor(Theme.primary)
                        .fontWeight(.bold)
                }

                // Character hasn't been typed yet - visibility depends on mode
                switch difficultyMode {
                case .fullText:
                    resultText = resultText + Text(String(correctChar))
                        .foregroundColor(.secondary)

                case .hiddenWords:
                    if correctChar == " " || correctChar == "\n" || isWordStart(at: index, in: target) {
                        resultText = resultText + Text(String(correctChar))
                            .foregroundColor(.secondary)
                    } else {
                        resultText = resultText + Text("_")
                            .foregroundColor(.secondary.opacity(0.3))
                    }

                case .firstLetter:
                    // Show spaces and newlines so paragraph structure is clear.
                    // Show only the first letter of each word; replace the
                    // remaining characters with a faint middle-dot so that
                    // word length is NOT revealed (harder than hiddenWords).
                    if correctChar == " " || correctChar == "\n" {
                        resultText = resultText + Text(String(correctChar))
                            .foregroundColor(.secondary.opacity(0.4))
                    } else if isWordStart(at: index, in: target) {
                        resultText = resultText + Text(String(correctChar))
                            .foregroundColor(.secondary)
                    } else {
                        resultText = resultText + Text("·")
                            .foregroundColor(.secondary.opacity(0.12))
                    }

                case .fillInTheBlank:
                    // Spaces and newlines are always visible so the surrounding
                    // context reads naturally.
                    if correctChar == " " || correctChar == "\n" {
                        resultText = resultText + Text(String(correctChar))
                            .foregroundColor(.secondary)
                    } else if keyWordMask[index] {
                        // Key word character – replace with an underscore
                        resultText = resultText + Text("_")
                            .foregroundColor(.secondary.opacity(0.35))
                    } else {
                        // Non-key word character – show faded, like Full Text
                        resultText = resultText + Text(String(correctChar))
                            .foregroundColor(.secondary)
                    }

                case .blankCanvas:
                    if correctChar == " " || correctChar == "\n" {
                        resultText = resultText + Text(String(correctChar))
                            .foregroundColor(.clear)
                    } else {
                        resultText = resultText + Text("_")
                            .foregroundColor(.secondary.opacity(0.15))
                    }
                }
            }
        }

        // Add cursor at end if we've typed everything
        if typed.count >= target.count {
            resultText = resultText + Text("|")
                .foregroundColor(Theme.primary)
                .fontWeight(.bold)
        }

        return resultText
    }
}

// MARK: - Flow Layout for Word Bubbles
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            let position = CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY)
            subviews[index].place(at: position, proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}

// Custom extension to allow indexing into a string by integer index
extension String {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}

// MARK: - Locked Mode Preview Sheet

/// Shows free users a non-interactive preview of how a locked difficulty mode
/// renders their actual verse, before pushing them to the paywall.
struct DifficultyModePreviewSheet: View {
    let mode: DifficultyMode
    let verseText: String
    let onUnlock: () -> Void
    @Environment(\.dismiss) private var dismiss

    /// Limit preview to the first ~120 chars so the sheet stays compact.
    private var sampleText: String {
        let trimmed = verseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 120 { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: 120)
        return String(trimmed[..<end]) + "…"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.15))
                            .frame(width: 64, height: 64)
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2)
                            .foregroundColor(Theme.primary)
                    }

                    Text(mode.rawValue)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(mode.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Live preview of the verse rendered in this mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)

                    Self.renderPreview(for: sampleText, mode: mode)
                        .font(.system(size: 18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                }
                .padding(.horizontal)

                Spacer()

                // CTA
                VStack(spacing: 12) {
                    Button(action: onUnlock) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Unlock All Modes")
                                .fontWeight(.semibold)
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

                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Mode Preview")
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
        }
        .presentationDetents([.medium, .large])
    }

    /// Render the verse as it would appear in the given mode (non-interactive).
    /// Mirrors the visibility rules in TypingView.buildColoredText().
    static func renderPreview(for target: String, mode: DifficultyMode) -> Text {
        var result = Text("")
        // Build a quick keyword mask for fill-in-the-blank.
        let punctuationCharacters = CharacterSet.punctuationCharacters

        func isKeyWord(_ word: String) -> Bool {
            let clean = word.unicodeScalars
                .filter { !punctuationCharacters.contains($0) }
                .map { String($0) }
                .joined()
            return clean.count > 4
        }

        func isWordStart(_ index: Int) -> Bool {
            if index == 0 { return true }
            let prev = target[target.index(target.startIndex, offsetBy: index - 1)]
            return prev == " " || prev == "\n"
        }

        // Precompute keyword mask
        var keyMask = Array(repeating: false, count: target.count)
        if mode == .fillInTheBlank {
            var start: Int? = nil
            for (i, ch) in target.enumerated() {
                if ch == " " || ch == "\n" {
                    if let s = start {
                        let word = String(target[
                            target.index(target.startIndex, offsetBy: s)
                            ..< target.index(target.startIndex, offsetBy: i)
                        ])
                        if isKeyWord(word) { for j in s..<i { keyMask[j] = true } }
                        start = nil
                    }
                } else if start == nil {
                    start = i
                }
            }
            if let s = start {
                let word = String(target[target.index(target.startIndex, offsetBy: s)...])
                if isKeyWord(word) { for j in s..<target.count { keyMask[j] = true } }
            }
        }

        for index in 0..<target.count {
            let ch = target[target.index(target.startIndex, offsetBy: index)]

            switch mode {
            case .fullText:
                result = result + Text(String(ch)).foregroundColor(.primary)

            case .hiddenWords:
                if ch == " " || ch == "\n" || isWordStart(index) {
                    result = result + Text(String(ch)).foregroundColor(.primary)
                } else {
                    result = result + Text("_").foregroundColor(.secondary.opacity(0.4))
                }

            case .firstLetter:
                if ch == " " || ch == "\n" {
                    result = result + Text(String(ch)).foregroundColor(.secondary)
                } else if isWordStart(index) {
                    result = result + Text(String(ch)).foregroundColor(.primary)
                } else {
                    result = result + Text("·").foregroundColor(.secondary.opacity(0.2))
                }

            case .fillInTheBlank:
                if ch == " " || ch == "\n" {
                    result = result + Text(String(ch)).foregroundColor(.secondary)
                } else if keyMask[index] {
                    result = result + Text("_").foregroundColor(.secondary.opacity(0.4))
                } else {
                    result = result + Text(String(ch)).foregroundColor(.primary)
                }

            case .blankCanvas:
                if ch == " " || ch == "\n" {
                    result = result + Text(String(ch))
                } else {
                    result = result + Text("_").foregroundColor(.secondary.opacity(0.25))
                }
            }
        }

        return result
    }
}

#Preview {
    NavigationStack {
        MemorizeView(
            item: MemorizeItemModel(
                title: "John 3:16",
                categoryName: "Bible Verses",
                memorizeText: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have eternal life"
            )
        )
    }
}
