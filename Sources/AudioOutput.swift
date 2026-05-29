import AVFoundation

/// Speaks answers via TTS, ducking other audio while it talks.
/// A new answer immediately interrupts one that's still playing.
@MainActor
final class AudioOutput: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var isSpeaking = false
    private let synth = AVSpeechSynthesizer()
    private var replacing = false   // true while we interrupt to start a new utterance

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synth.isSpeaking {
            replacing = true
            synth.stopSpeaking(at: .immediate)   // clear the current answer first
        }

        AudioSessionManager.shared.setDucking(true)
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        isSpeaking = true
        synth.speak(utterance)
    }

    /// Stop any current speech (e.g., when a new answer is requested).
    func stop() {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            AudioSessionManager.shared.setDucking(false)
            NotificationCenter.default.post(name: .speechOutputFinished, object: nil)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                       didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // If we cancelled only to start a new utterance, keep ducking.
            if self.replacing {
                self.replacing = false
                return
            }
            self.isSpeaking = false
            AudioSessionManager.shared.setDucking(false)
            NotificationCenter.default.post(name: .speechOutputFinished, object: nil)
        }
    }
}
