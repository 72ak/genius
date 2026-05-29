import Foundation

#if canImport(SwiftLlama)
import SwiftLlama
#endif

/// On-device open-weight Qwen provider backed by a GGUF runtime when available.
struct LocalQwenProvider: AnswerProvider {
    static let modelName = "Qwen3-4B-GGUF"
    static let preferredFileName = "qwen3-4b.gguf"
    static let installHint = "Add qwen3-4b.gguf to the Genius Documents folder, then reopen the app or switch models."
    static let notReadyReason = "Local Qwen is selected, but no GGUF model file is installed. \(installHint)"

    var isReady: Bool {
        Self.modelURL() != nil
    }

    func answer(context: String, facts: String) async throws -> String {
        guard let modelURL = Self.modelURL() else {
            throw LocalQwenError.modelMissing
        }

        var prompt = ""
        if !facts.isEmpty {
            prompt += "Relevant facts from the web (use what's helpful, ignore the rest):\n\(facts)\n\n"
        }
        prompt += "/no_think\nConversation so far:\n\"\(context)\"\n\nWhat should I say?"

        return try await LocalQwenEngine.shared.answer(
            system: "/no_think\n\(geniusInstructions)",
            prompt: prompt,
            modelURL: modelURL
        )
    }

    static func modelURL() -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let documents else { return nil }

        let preferred = documents.appendingPathComponent(preferredFileName)
        if FileManager.default.fileExists(atPath: preferred.path) {
            return preferred
        }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: documents,
            includingPropertiesForKeys: nil
        )) ?? []

        return urls.first { url in
            let name = url.lastPathComponent.lowercased()
            return name.hasSuffix(".gguf") && name.contains("qwen") && (name.contains("4b") || name.contains("3-4"))
        }
    }
}

private actor LocalQwenEngine {
    static let shared = LocalQwenEngine()

    private var loadedModelURL: URL?

    #if canImport(SwiftLlama)
    private var service: LlamaService?
    #endif

    func answer(system: String, prompt: String, modelURL: URL) async throws -> String {
        #if canImport(SwiftLlama)
        let service = try loadService(modelURL: modelURL)
        let messages = [
            LlamaChatMessage(role: .system, content: system),
            LlamaChatMessage(role: .user, content: prompt)
        ]
        let sampling = LlamaSamplingConfig(
            temperature: 0.2,
            seed: UInt32.random(in: 1...UInt32.max),
            topP: 0.9,
            topK: 40
        )
        return try await service.respond(to: messages, samplingConfig: sampling)
        #else
        throw LocalQwenError.runtimeUnavailable
        #endif
    }

    #if canImport(SwiftLlama)
    private func loadService(modelURL: URL) throws -> LlamaService {
        if loadedModelURL == modelURL, let service {
            return service
        }

        let newService = LlamaService(
            modelUrl: modelURL,
            config: LlamaConfig(batchSize: 256, maxTokenCount: 2048, useGPU: true)
        )
        loadedModelURL = modelURL
        service = newService
        return newService
    }
    #endif
}

private enum LocalQwenError: LocalizedError {
    case modelMissing
    case runtimeUnavailable

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return LocalQwenProvider.notReadyReason
        case .runtimeUnavailable:
            return "Local Qwen runtime is not linked into this build."
        }
    }
}
