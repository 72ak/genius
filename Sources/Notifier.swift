import UserNotifications

/// Local notifications that show the answer on the lock screen / banner.
enum Notifier {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func post(answer: String) {
        let content = UNMutableNotificationContent()
        content.title = "Genius"
        content.body = answer
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
