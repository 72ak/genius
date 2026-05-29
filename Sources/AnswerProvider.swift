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
You feed the user the answer to whatever was just asked or discussed, so they sound brilliant.
Output rules — follow exactly:
- Lead with the answer. No preamble, no filler, no acknowledgements.
- Never start with words like "Well", "So", "Sure", "Great question", "I think", "That's a good point", or "Let me".
- If it's a direct question, give the direct answer first, then at most one sentence of why.
- If several points are needed, use short bullet points (each a few words). Otherwise 1–2 tight sentences.
- Be specific and confident. Plain spoken words. No markdown headers, no hedging.
"""

/// Used when no on-device model is available, so the app stays functional.
struct UnavailableProvider: AnswerProvider {
    var isReady: Bool { false }
    func answer(context: String, facts: String) async throws -> String {
        "On-device model isn't available. Make sure Apple Intelligence is turned on in Settings, then reopen Genius."
    }
}
