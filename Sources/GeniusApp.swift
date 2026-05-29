import SwiftUI
import UserNotifications

/// Shows notification banners even while the app is in the foreground.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@main
struct GeniusApp: App {
    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url == URL(string: "genius://toggle-listening") {
                        NotificationCenter.default.post(name: .toggleListeningFromShortcut, object: nil)
                    }
                }
        }
    }
}
