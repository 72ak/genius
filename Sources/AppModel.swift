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
    @Published var latestAnswer = ""
    @Published var isThinking = false
    @Published var statusMessage = "Starting…"

    let transcriber = Transcriber()
    let output = AudioOutput()

    private let provider: AnswerProvider
    private let remote = RemoteControl()
    private var cancellables = Set<AnyCancellable>()

    init() {
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            provider = FoundationModelsProvider()
            #else
            provider = UnavailableProvider()
            #endif
        } else {
            provider = UnavailableProvider()
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
            Task { @MainActor in self?.updateRemoteControl() }
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
        statusMessage = provider.isReady ? "Listening…" : "Listening — but the on-device model isn't ready."
    }

    func triggerAnswer() {
        guard !isThinking else { return }
        Task {
            isThinking = true
            defer { isThinking = false }

            let context = await transcriber.recall(seconds: recallSeconds)
            guard !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                statusMessage = "Didn't catch anything to answer yet."
                return
            }

            do {
                var facts = ""
                if webSearchEnabled {
                    statusMessage = "Looking it up…"
                    facts = await WebSearch.lookup(SearchQuery.extract(from: context))
                }
                statusMessage = "Thinking…"
                let answer = try await provider.answer(context: context, facts: facts)
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
}
