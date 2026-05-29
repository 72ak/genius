import Foundation

/// The "brain." Swappable so we can move between Apple's on-device model,
/// an open-source model (llama.cpp), or a cloud API without touching the app.
protocol AnswerProvider {
    /// Whether this provider can currently answer (e.g., model is available).
    var isReady: Bool { get }

    /// Produce a short, smart answer given recent conversation context and
    /// optional facts pulled from the web.
    func answer(context: String, facts: String) async throws -> String
}

/// The shared persona/instructions for every provider.
let geniusInstructions = """
You are the user's brilliant, quick-witted companion whispering in their ear. \
You are given a snippet of a real conversation the user is part of. Infer the most \
useful thing for the user to say next: answer the question that was asked, supply the \
key fact, or add a sharp insight that makes the user sound like a genius. \
Be confident and specific. Keep it to 1–3 short spoken sentences. \
No preamble, no markdown, no lists — just the words to say.
"""

/// Used when no on-device model is available, so the app stays functional.
struct UnavailableProvider: AnswerProvider {
    var isReady: Bool { false }
    func answer(context: String, facts: String) async throws -> String {
        "On-device model isn't available. Make sure Apple Intelligence is turned on in Settings, then reopen Genius."
    }
}
