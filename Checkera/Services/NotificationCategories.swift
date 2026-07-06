import Foundation
import UserNotifications

enum NotificationCategoryID {
    static let regular = "regular_task"
    static let goldenAlarm = "golden_alarm"
}

enum NotificationActionID {
    static let snooze15 = "SNOOZE_15"
    static let dismiss = "DISMISS"
}

enum NotificationCategoryRegistrar {

    static func registerAll(center: UNUserNotificationCenter = .current()) {
        center.setNotificationCategories([makeGoldenAlarm(), makeRegular()])
    }

    private static func makeGoldenAlarm() -> UNNotificationCategory {
        let snooze = UNNotificationAction(
            identifier: NotificationActionID.snooze15,
            title: String(
                localized: "Snooze 15 min",
                comment: "Snooze action button on the golden task alarm notification."
            ),
            options: []
        )
        let dismiss = UNNotificationAction(
            identifier: NotificationActionID.dismiss,
            title: String(
                localized: "Dismiss",
                comment: "Dismiss action button on the golden task alarm notification."
            ),
            options: [.destructive]
        )
        return UNNotificationCategory(
            identifier: NotificationCategoryID.goldenAlarm,
            actions: [snooze, dismiss],
            intentIdentifiers: [],
            options: []
        )
    }

    private static func makeRegular() -> UNNotificationCategory {
        UNNotificationCategory(
            identifier: NotificationCategoryID.regular,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
    }
}
