import Foundation

/// A timestamped, rolling record of finalized transcribed speech.
/// The in-progress (live) phrase is held separately by the Transcriber.
actor TranscriptBuffer {
    private struct Segment {
        let text: String
        let date: Date
    }

    private var segments: [Segment] = []
    private let maxAge: TimeInterval = 6 * 60 // keep a little over 5 minutes

    func append(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        segments.append(Segment(text: trimmed, date: Date()))
        prune()
    }

    /// Text finalized within the last `seconds`.
    func recent(seconds: TimeInterval) -> String {
        let cutoff = Date().addingTimeInterval(-seconds)
        return segments.filter { $0.date >= cutoff }
            .map(\.text)
            .joined(separator: " ")
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        segments.removeAll { $0.date < cutoff }
    }
}
