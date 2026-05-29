import Foundation
import Speech
import AVFoundation

/// Continuous on-device live transcription via SFSpeechRecognizer.
/// A single recognition task accumulates text; we recycle it periodically so
/// finalized chunks land in the buffer with reasonably recent timestamps.
@MainActor
final class Transcriber: ObservableObject {
    @Published var livePartial: String = ""
    @Published var transcript: String = ""   // accumulated conversation (for display)
    @Published var isRunning = false
    @Published var authorized = false

    /// Called when a phrase is finalized (used by auto-mode).
    var onFinalized: ((String) -> Void)?

    let buffer = TranscriptBuffer()

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var restartTimer: Timer?

    func requestAuthorization() async {
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        let micGranted = await AVAudioApplication.requestRecordPermission()
        authorized = (speechStatus == .authorized) && micGranted
    }

    func start() {
        guard authorized, !isRunning,
              let recognizer, recognizer.isAvailable else { return }
        do {
            try AudioSessionManager.shared.configureForListening()
            installTap()
            audioEngine.prepare()
            try audioEngine.start()
            beginTask()
            isRunning = true
            restartTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.recycleTask() }
            }
        } catch {
            print("Transcriber start error: \(error)")
        }
    }

    func stop() {
        restartTimer?.invalidate()
        restartTimer = nil
        endTask(commit: true)
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRunning = false
    }

    func recall(seconds: TimeInterval) async -> String {
        let finalized = await buffer.recent(seconds: seconds)
        return [finalized, livePartial]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Internals

    private func installTap() {
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }
    }

    private func beginTask() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        self.request = request

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.livePartial = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.commitLive()
                        self.restartTask()   // keep listening — don't go deaf after a pause
                    }
                }
                if error != nil {
                    self.restartTask()
                }
            }
        }
    }

    /// Start a fresh recognition task immediately (the previous one has ended).
    private func restartTask() {
        guard isRunning else { return }
        task = nil
        request?.endAudio()
        request = nil
        beginTask()
    }

    private func recycleTask() {
        endTask(commit: true)
        beginTask()
    }

    private func endTask(commit: Bool) {
        if commit { commitLive() }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    private func commitLive() {
        let text = livePartial.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        livePartial = ""
        appendToTranscript(text)
        Task { await buffer.append(text) }
        onFinalized?(text)
    }

    private func appendToTranscript(_ text: String) {
        transcript = transcript.isEmpty ? text : transcript + " " + text
        if transcript.count > 1500 {
            transcript = String(transcript.suffix(1500))
        }
    }
}
