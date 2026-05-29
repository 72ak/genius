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
Respond ONLY as short bullet points. Follow exactly:
- Output 1 to 4 bullets, each on its own line starting with "- ".
- Each bullet is a few words up to one short sentence. Lead with the answer or key fact.
- No intro, no filler, no closing line. Never write "Well", "So", "Sure", "Great question", "I think", "Let me", or "That's a good".
- Be specific and confident. Plain words. No markdown headers, no nested bullets.
"""

/// Used when no on-device model is available, so the app stays functional.
struct UnavailableProvider: AnswerProvider {
    var isReady: Bool { false }
    func answer(context: String, facts: String) async throws -> String {
        "On-device model isn't available. Make sure Apple Intelligence is turned on in Settings, then reopen Genius."
    }
}
