import Foundation

struct GeminiProvider: AnswerProvider {
    static let defaultModelName = "gemini-3.1-flash-lite"

    let apiKey: String
    let modelName: String

    var isReady: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func answer(context: String, facts: String) async throws -> String {
        var prompt = ""
        if !facts.isEmpty {
            prompt += "Relevant facts from the web (use what's helpful, ignore the rest):\n\(facts)\n\n"
        }
        prompt += "Conversation so far:\n\"\(context)\"\n\nWhat should I say?"

        let model = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent") else {
            throw GeminiError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.httpMethod = "POST"
        request.setValue(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(
            system_instruction: Content(parts: [Part(text: geniusInstructions)]),
            contents: [Content(parts: [Part(text: prompt)])],
            generationConfig: GenerationConfig(
                maxOutputTokens: 120,
                temperature: 0.2,
                topP: 0.9,
                thinkingConfig: ThinkingConfig(thinkingLevel: "minimal")
            )
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)

        if let message = decoded.error?.message, !message.isEmpty {
            throw GeminiError.api(message)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GeminiError.api("Gemini request failed (\(http.statusCode)).")
        }

        let text = decoded.candidates?
            .flatMap { $0.content.parts }
            .filter { $0.thought != true }
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !text.isEmpty else { throw GeminiError.emptyResponse }
        return text
    }
}

private struct RequestBody: Encodable {
    let system_instruction: Content
    let contents: [Content]
    let generationConfig: GenerationConfig
}

private struct Content: Codable {
    let parts: [Part]
}

private struct Part: Codable {
    let text: String?
    let thought: Bool?

    init(text: String?, thought: Bool? = nil) {
        self.text = text
        self.thought = thought
    }
}

private struct GenerationConfig: Encodable {
    let maxOutputTokens: Int
    let temperature: Double
    let topP: Double
    let thinkingConfig: ThinkingConfig
}

private struct ThinkingConfig: Encodable {
    let thinkingLevel: String
}

private struct ResponseBody: Decodable {
    let candidates: [Candidate]?
    let error: APIError?
}

private struct Candidate: Decodable {
    let content: Content
}

private struct APIError: Decodable {
    let message: String
}

private enum GeminiError: LocalizedError {
    case invalidURL
    case emptyResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Gemini URL."
        case .emptyResponse:
            return "Gemini returned an empty answer."
        case .api(let message):
            return message
        }
    }
}
