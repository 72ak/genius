import Foundation

/// Placeholder for an on-device open-weight Qwen runtime.
/// The target model is Qwen/Qwen3.6-27B; it still needs a mobile inference
/// engine (llama.cpp/MLC/etc.) plus a quantized model file before it can answer.
struct LocalQwenProvider: AnswerProvider {
    static let modelName = "Qwen3.6-27B"

    var isReady: Bool { false }

    func answer(context: String, facts: String) async throws -> String {
        "Local Qwen isn't installed yet. Add an iOS inference runtime and a quantized Qwen3.6-27B model file, then switch this provider on."
    }
}
