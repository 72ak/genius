import Foundation

#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
struct ListeningActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isListening: Bool
        var status: String
    }

    var name: String
}
#endif
