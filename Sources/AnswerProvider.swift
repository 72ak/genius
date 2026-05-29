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

enum BrainMode: String, CaseIterable, Identifiable {
    case appleOnDevice
    case localQwen
    case geminiFlashLite

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appleOnDevice:
            return "Apple"
        case .localQwen:
            return "Qwen local"
        case .geminiFlashLite:
            return "Gemini"
        }
    }
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

enum AnswerFormatter {
    static func bulletOnly(_ text: String) -> String {
        let trimmed = stripThinkBlocks(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { cleanBulletText($0) }
            .filter { !$0.isEmpty }

        let candidates: [String]
        if lines.count > 1 {
            candidates = lines
        } else {
            candidates = splitSentences(trimmed).map(cleanBulletText).filter { !$0.isEmpty }
        }

        return candidates
            .prefix(4)
            .map { "- \($0)" }
            .joined(separator: "\n")
    }

    private static func cleanBulletText(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasPrefix("-") || text.hasPrefix("*") {
            text.removeFirst()
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let dot = text.firstIndex(of: ".") {
            let prefix = text[..<dot]
            if !prefix.isEmpty, prefix.allSatisfy({ $0.isNumber }) {
                text = String(text[text.index(after: dot)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return text
    }

    private static func splitSentences(_ text: String) -> [String] {
        text.split(whereSeparator: { ".!?".contains($0) })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func stripThinkBlocks(_ text: String) -> String {
        var output = text
        while let start = output.range(of: "<think>", options: .caseInsensitive),
              let end = output.range(of: "</think>", options: .caseInsensitive, range: start.upperBound..<output.endIndex) {
            output.removeSubrange(start.lowerBound..<end.upperBound)
        }
        return output
    }
}
