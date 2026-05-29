import Foundation

/// Placeholder for an on-device open-weight Qwen runtime.
/// The target model is Qwen/Qwen3-4B-GGUF; it still needs a mobile inference
/// engine (llama.cpp/MLC/etc.) plus a quantized model file before it can answer.
struct LocalQwenProvider: AnswerProvider {
    static let modelName = "Qwen3-4B-GGUF"
    static let notReadyReason = "Qwen needs a native iOS inference runtime plus the Qwen3-4B-GGUF model file. This build only adds the UI/provider target."

    var isReady: Bool { false }

    func answer(context: String, facts: String) async throws -> String {
        LocalQwenProvider.notReadyReason
    }
}
