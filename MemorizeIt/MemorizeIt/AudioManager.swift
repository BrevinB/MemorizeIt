//
//  AudioManager.swift
//  MemorizeIt
//
//  Audio practice: speak the verse to the user (Listen) and let the user
//  recite the verse to score it (Voice mode).
//

import Foundation
import AVFoundation
import Speech
import SwiftUI

// MARK: - Listen Mode (text-to-speech)

/// Wraps AVSpeechSynthesizer with simple play/stop state for SwiftUI.
@MainActor
final class VerseSpeaker: NSObject, ObservableObject {
    static let shared = VerseSpeaker()

    @Published private(set) var isSpeaking: Bool = false

    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}

extension VerseSpeaker: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}

/// Toolbar button that toggles narration of the given text.
struct ListenButton: View {
    let text: String
    @StateObject private var speaker = VerseSpeaker.shared

    var body: some View {
        Button {
            if speaker.isSpeaking {
                speaker.stop()
            } else {
                speaker.speak(text)
                HapticManager.shared.impact(style: .light)
            }
        } label: {
            Image(systemName: speaker.isSpeaking ? "stop.circle.fill" : "speaker.wave.2.fill")
                .foregroundColor(speaker.isSpeaking ? .red : Theme.primary)
        }
        .accessibilityLabel(speaker.isSpeaking ? "Stop narration" : "Listen to verse")
    }
}

// MARK: - Voice Mode (speech-to-text)

enum VoiceAuthorizationStatus: Equatable {
    case unknown, authorized, denied(String)
}

/// Wraps SFSpeechRecognizer + AVAudioEngine for live transcription of the user
/// reciting the verse. Comparisons happen in the UI layer (VoicePracticeView).
@MainActor
final class VerseListener: NSObject, ObservableObject {
    @Published private(set) var transcript: String = ""
    @Published private(set) var isListening: Bool = false
    @Published private(set) var isFinalizing: Bool = false
    @Published private(set) var authorization: VoiceAuthorizationStatus = .unknown
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var finalizationContinuation: CheckedContinuation<Void, Never>?

    // MARK: Authorization

    func requestAuthorization() async {
        let speechStatus = await withCheckedContinuation { (cont: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            authorization = .denied("Speech recognition permission was denied. Enable it in Settings to use Voice mode.")
            return
        }

        let micGranted: Bool
        if #available(iOS 17, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }

        if micGranted {
            authorization = .authorized
        } else {
            authorization = .denied("Microphone permission was denied. Enable it in Settings to use Voice mode.")
        }
    }

    // MARK: Recording

    func start() throws {
        // Tear down any prior session synchronously
        hardStop()

        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "VerseListener", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition is unavailable right now. Check your network or try again."])
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        // Prefer on-device when supported - no network round-trip, no 1-min cap.
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        if #available(iOS 16, *) {
            // Show punctuation so the transcript reads naturally; the
            // comparison in VoicePracticeView normalizes both sides anyway.
            req.addsPunctuation = true
        }
        request = req

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let newText = result.bestTranscription.formattedString
                let isFinal = result.isFinal
                Task { @MainActor in
                    // SFSpeechRecognizer occasionally delivers a final result
                    // with an empty `formattedString` — never clobber a good
                    // partial transcript with that.
                    if !newText.isEmpty {
                        self.transcript = newText
                    }
                    if isFinal {
                        self.resumeFinalization()
                    }
                }
            }
            if let error {
                Task { @MainActor in
                    // Code 1110 is "No speech detected" — non-fatal during quick taps.
                    let nsError = error as NSError
                    if nsError.code != 1110 {
                        self.errorMessage = error.localizedDescription
                    }
                    self.hardStop()
                    self.resumeFinalization()
                }
            }
        }

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    /// Gracefully end recording and wait for the recognizer to deliver its
    /// final transcript. Caller should `await` this before scoring so the tail
    /// of the recitation isn't dropped.
    func stop() async {
        guard isListening else { return }

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        isListening = false
        isFinalizing = true

        // Wait for either the recognizer's isFinal callback or a short timeout
        // so the UI never hangs if recognition stalls.
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            finalizationContinuation = cont
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run { self?.resumeFinalization() }
            }
        }

        isFinalizing = false
        request = nil
        task = nil
    }

    /// Abort recording immediately without waiting for the final transcript.
    /// Used when navigating away mid-session.
    func cancel() {
        hardStop()
        resumeFinalization()
    }

    /// Tears down audio + recognition resources without waiting for a final
    /// result. Safe to call from error paths.
    private func hardStop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        isListening = false
        isFinalizing = false
    }

    private func resumeFinalization() {
        if let cont = finalizationContinuation {
            finalizationContinuation = nil
            cont.resume()
        }
    }

    func reset() {
        cancel()
        transcript = ""
        errorMessage = nil
    }
}
