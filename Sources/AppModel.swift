import Foundation
import Combine
import SwiftUI
import AVFoundation

/// Orchestrates listening → recall → answer → speak/notify.
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var recallSeconds: Double = 60      // 30...300
    @Published var listeningEnabled = true {
        didSet {
            UserDefaults.standard.set(listeningEnabled, forKey: "listeningEnabled")
            if didFinishInit { applyListeningState() }
        }
    }
    @Published var autoMode = false
    @Published var webSearchEnabled = true
    @Published var headphoneButtonEnabled = true { didSet { updateRemoteControl() } }
    @Published var brainMode: BrainMode = BrainMode(rawValue: UserDefaults.standard.string(forKey: "brainMode") ?? "") ?? .appleOnDevice {
        didSet {
            UserDefaults.standard.set(brainMode.rawValue, forKey: "brainMode")
            updateReadyStatus()
        }
    }
    @Published var geminiAPIKey: String = "" {
        didSet {
            KeychainStore.save(geminiAPIKey, account: "gemini_api_key")
            updateReadyStatus()
        }
    }
    @Published var appleModelPreference: String = "System default" {
        didSet { UserDefaults.standard.set(appleModelPreference, forKey: "appleModelPreference") }
    }
    @Published var qwenModelFileName: String = LocalQwenProvider.defaultPreferredFileName {
        didSet {
            UserDefaults.standard.set(qwenModelFileName, forKey: "qwenModelFileName")
            updateReadyStatus()
        }
    }
    @Published var geminiModelName: String = GeminiProvider.defaultModelName {
        didSet {
            UserDefaults.standard.set(geminiModelName, forKey: "geminiModelName")
            updateReadyStatus()
        }
    }
    @Published var latestAnswer = ""
    @Published var lastFacts = ""
    @Published var isThinking = false
    let localQwenModelName = LocalQwenProvider.modelName
    let geminiModelOptions = ["gemini-3.1-flash-lite", "gemini-3.5-flash", "gemini-2.5-flash-lite"]
    let appleModelOptions = ["System default"]
    @Published var statusMessage = "Starting…"

    let transcriber = Transcriber()
    let output = AudioOutput()

    private let appleProvider: AnswerProvider
    private let remote = RemoteControl()
    private var cancellables = Set<AnyCancellable>()
    private var didFinishInit = false

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
        listeningEnabled = UserDefaults.standard.object(forKey: "listeningEnabled") as? Bool ?? true
        geminiAPIKey = KeychainStore.read(account: "gemini_api_key")
        appleModelPreference = UserDefaults.standard.string(forKey: "appleModelPreference") ?? "System default"
        qwenModelFileName = UserDefaults.standard.string(forKey: "qwenModelFileName") ?? LocalQwenProvider.defaultPreferredFileName
        geminiModelName = UserDefaults.standard.string(forKey: "geminiModelName") ?? GeminiProvider.defaultModelName

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
        NotificationCenter.default.addObserver(
            forName: .toggleListeningFromShortcut, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.toggleListening() }
        }
        NotificationCenter.default.addObserver(
            forName: .audioSessionReconfigured, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recoverListeningSoon() }
        }
        NotificationCenter.default.addObserver(
            forName: .speechOutputFinished, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.recoverListeningSoon() }
        }
        didFinishInit = true
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
        applyListeningState()
        updateRemoteControl()
        updateReadyStatus()
    }

    func triggerAnswer() {
        guard !isThinking else { return }
        if listeningEnabled { transcriber.ensureRunning() }
        Task {
            isThinking = true
            output.stop()   // clear any answer that's still playing
            defer {
                isThinking = false
                if self.listeningEnabled { self.transcriber.ensureRunning() }
            }

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
                if listeningEnabled { transcriber.ensureRunning() }
                if AudioSessionManager.shared.headphonesConnected {
                    output.speak(answer)
                    recoverListeningSoon()
                }
                statusMessage = "Listening…"
            } catch {
                statusMessage = "Answer failed: \(error.localizedDescription)"
            }
        }
    }

    func clearTranscript() {
        Task {
            await transcriber.clearTranscript()
            updateReadyStatus()
        }
    }

    func toggleListening() {
        listeningEnabled.toggle()
    }

    private func selectedProvider() -> AnswerProvider {
        switch brainMode {
        case .appleOnDevice:
            appleProvider
        case .localQwen:
            LocalQwenProvider(preferredFileName: qwenModelFileName)
        case .geminiFlashLite:
            GeminiProvider(apiKey: geminiAPIKey, modelName: geminiModelName)
        }
    }

    private func recoverListeningSoon() {
        guard listeningEnabled else { return }
        transcriber.ensureRunning()
        Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await MainActor.run {
                guard self.listeningEnabled else { return }
                self.transcriber.ensureRunning()
            }
        }
    }

    private func applyListeningState() {
        if listeningEnabled {
            transcriber.ensureRunning()
        } else {
            transcriber.stop()
        }
        updateReadyStatus()
    }

    private func updateReadyStatus() {
        guard transcriber.authorized else { return }
        guard listeningEnabled else {
            statusMessage = "Listening off."
            LiveActivityManager.shared.update(isListening: false, status: statusMessage)
            return
        }
        let provider = selectedProvider()
        statusMessage = provider.isReady ? "Listening…" : notReadyMessage()
        LiveActivityManager.shared.update(isListening: true, status: statusMessage)
    }

    private func notReadyMessage() -> String {
        switch brainMode {
        case .appleOnDevice:
            return "Listening — but the on-device model isn't ready."
        case .localQwen:
            return "Local Qwen is selected, but no GGUF model file is installed. \(LocalQwenProvider.installHint(fileName: qwenModelFileName))"
        case .geminiFlashLite:
            return "Gemini selected - add your Gemini API key to answer with Flash-Lite."
        }
    }
}

extension Notification.Name {
    static let toggleListeningFromShortcut = Notification.Name("toggleListeningFromShortcut")
    static let audioSessionReconfigured = Notification.Name("audioSessionReconfigured")
    static let speechOutputFinished = Notification.Name("speechOutputFinished")
}
