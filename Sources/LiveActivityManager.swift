import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private init() {}

    func update(isListening: Bool, status: String) {
        #if canImport(ActivityKit)
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let state = ListeningActivityAttributes.ContentState(
            isListening: isListening,
            status: status
        )
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            if let activity = Activity<ListeningActivityAttributes>.activities.first {
                await activity.update(content)
            } else {
                _ = try? Activity.request(
                    attributes: ListeningActivityAttributes(name: "Genius"),
                    content: content,
                    pushType: nil
                )
            }
        }
        #endif
    }
}
