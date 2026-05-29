import AppIntents

/// Lets the Action Button, Back-Tap, or Siri trigger an answer.
struct AskGeniusIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Genius"
    static var description = IntentDescription("Have Genius answer based on what it just heard.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.triggerAnswer()
        return .result()
    }
}

struct GeniusShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskGeniusIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "\(.applicationName) answer this"
            ],
            shortTitle: "Ask Genius",
            systemImageName: "brain"
        )
    }
}
