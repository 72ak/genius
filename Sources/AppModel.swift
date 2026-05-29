import Foundation
import Combine
import SwiftUI
import AVFoundation

/// Orchestrates listening → recall → answer → speak/notify.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var recallSeconds: Double = 60      // 30...300
    @Published var autoMode = false
    @Published var webSearchEnabled = true
    @Published var headphoneButtonEnabled = true { didSet { updateRemoteControl() } }
    @Published var brainMode: BrainMode = BrainMode(rawValue: UserDefaults.standard.string(forKey: "brainMode") ?? "") ?? .appleOnDevice {
        didSet {
            UserDefaults.standard.set(brainMode.rawValue, forKey: "brainMode")
            updateReadyStatus()
        }
    }
    @Published var latestAnswer = ""
    @Published var lastFacts = ""
    @Published var isThinking = false
    let localQwenModelName = LocalQwenProvider.modelName
    @Published var statusMessage = "Starting…"

    let transcriber = Transcriber()
    let output = AudioOutput()

    private let appleProvider: AnswerProvider
    private let remote = RemoteControl()
    private var cancellables = Set<AnyCancellable>()

    init() {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            appleProvider = FoundationModelsProvider()
            #else
            appleProvider = UnavailableProvider()
            #endif
        } else {
            appleProvider = UnavailableProvider()
        }
        // Re-publish nested ObservableObjects so the view updates on their changes.
        transcriber.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        output.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        remote.onTrigger = { [weak self] in self?.triggerAnswer() }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                AudioSessionManager.shared.preferBuiltInMic()
                self?.updateRemoteControl()
            }
        }
    }

    func updateRemoteControl() {
        if headphoneButtonEnabled && AudioSessionManager.shared.headphonesConnected {
            remote.enable()
        } else {
            remote.disable()
        }
    }

    func onAppear() async {
        await Notifier.requestAuthorization()
        await transcriber.requestAuthorization()

        transcriber.onFinalized = { [weak self] text in
            guard let self, self.autoMode, !self.isThinking, !self.output.isSpeaking else { return }
            if text.contains("?") { self.triggerAnswer() }
        }

        guard transcriber.authorized else {
            statusMessage = "Microphone & Speech permission needed (Settings ▸ Genius)."
            return
        }
        transcriber.start()
        updateRemoteControl()
        updateReadyStatus()
    }

    func triggerAnswer() {
        guard !isThinking else { return }
        Task {
            isThinking = true
            output.stop()   // clear any answer that's still playing
            defer { isThinking = false }

            let context = await transcriber.recall(seconds: recallSeconds)
            guard !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                statusMessage = "Didn't catch anything to answer yet."
                return
            }

            do {
                let provider = selectedProvider()
                guard provider.isReady else {
                    statusMessage = notReadyMessage()
                    return
                }

                var facts = ""
                if webSearchEnabled {
                    statusMessage = "Looking it up…"
                    facts = await WebSearch.lookup(SearchQuery.extract(from: context))
                }
                lastFacts = facts
                statusMessage = "Thinking…"
                let answer = AnswerFormatter.bulletOnly(try await provider.answer(context: context, facts: facts))
                latestAnswer = answer
                Notifier.post(answer: answer)
                if AudioSessionManager.shared.headphonesConnected {
                    output.speak(answer)
                }
                statusMessage = "Listening…"
            } catch {
                statusMessage = "Answer failed: \(error.localizedDescription)"
            }
        }
    }

    private func selectedProvider() -> AnswerProvider {
        switch brainMode {
        case .appleOnDevice:
            appleProvider
        case .localQwen:
            LocalQwenProvider()
        }
    }

    private func updateReadyStatus() {
        guard transcriber.authorized else { return }
        let provider = selectedProvider()
        statusMessage = provider.isReady ? "Listening…" : notReadyMessage()
    }

    private func notReadyMessage() -> String {
        switch brainMode {
        case .appleOnDevice:
            return "Listening — but the on-device model isn't ready."
        case .localQwen:
            return "Local Qwen selected — runtime/model file not installed yet."
        }
    }
}
