import Foundation

/// Free, keyless web lookups: DuckDuckGo Instant Answers + Wikipedia.
/// Best-effort — returns a short string of facts, or "" if nothing useful.
enum WebSearch {
    static func lookup(_ query: String) async -> String {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return "" }
        async let ddg = duckDuckGo(q)
        async let wiki = wikipedia(q)
        let parts = [await ddg, await wiki].filter { !$0.isEmpty }
        return parts.joined(separator: "\n").prefixWords(120)
    }

    private static func duckDuckGo(_ q: String) async -> String {
        guard let url = URL(string:
            "https://api.duckduckgo.com/?q=\(q.urlEncoded)&format=json&no_html=1&skip_disambig=1")
        else { return "" }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return "" }

        if let answer = json["Answer"] as? String, !answer.isEmpty { return answer }
        if let abstract = json["AbstractText"] as? String, !abstract.isEmpty { return abstract }
        if let related = json["RelatedTopics"] as? [[String: Any]] {
            let texts = related.compactMap { $0["Text"] as? String }.prefix(2)
            if !texts.isEmpty { return texts.joined(separator: " ") }
        }
        return ""
    }

    private static func wikipedia(_ q: String) async -> String {
        guard let searchURL = URL(string:
            "https://en.wikipedia.org/w/api.php?action=opensearch&limit=1&format=json&search=\(q.urlEncoded)")
        else { return "" }
        guard let (data, _) = try? await URLSession.shared.data(from: searchURL),
              let arr = try? JSONSerialization.jsonObject(with: data) as? [Any],
              arr.count >= 2,
              let titles = arr[1] as? [String],
              let title = titles.first
        else { return "" }

        let pathTitle = title.replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let sumURL = URL(string:
            "https://en.wikipedia.org/api/rest_v1/page/summary/\(pathTitle)"),
              let (sdata, _) = try? await URLSession.shared.data(from: sumURL),
              let sjson = try? JSONSerialization.jsonObject(with: sdata) as? [String: Any],
              let extract = sjson["extract"] as? String
        else { return "" }
        return extract
    }
}

/// Pulls a focused search query out of the recent transcript.
enum SearchQuery {
    static func extract(from context: String) -> String {
        if let q = context.range(of: "?", options: .backwards) {
            let words = context[..<q.upperBound].split(separator: " ").suffix(15)
            return words.joined(separator: " ")
        }
        return context.split(separator: " ").suffix(12).joined(separator: " ")
    }
}

private extension String {
    var urlEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
    func prefixWords(_ n: Int) -> String {
        let words = split(separator: " ")
        return words.count <= n ? self : words.prefix(n).joined(separator: " ") + "…"
    }
}
