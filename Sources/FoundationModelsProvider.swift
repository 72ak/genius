import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Brain backed by Apple's built-in on-device model (iOS 26+).
@available(iOS 26.0, *)
final class FoundationModelsProvider: AnswerProvider {
    var isReady: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    func answer(context: String) async throws -> String {
        let session = LanguageModelSession {
            geniusInstructions
        }
        let prompt = "Conversation so far:\n\"\(context)\"\n\nWhat should I say?"
        let response = try await session.respond(to: prompt)
        return response.content
    }
}
#endif
