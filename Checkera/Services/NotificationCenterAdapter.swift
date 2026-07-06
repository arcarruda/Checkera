import Foundation
import UserNotifications

protocol NotificationCenterAdapter {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func schedule(
        identifier: String,
        title: String,
        body: String,
        soundName: String?,
        categoryIdentifier: String?,
        interruptionLevel: UNNotificationInterruptionLevel,
        components: DateComponents
    ) async throws
    func cancelRequests(identifiers: [String]) async
}

struct LiveNotificationCenter: NotificationCenterAdapter {

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
    }

    func schedule(
        identifier: String,
        title: String,
        body: String,
        soundName: String?,
        categoryIdentifier: String?,
        interruptionLevel: UNNotificationInterruptionLevel,
        components: DateComponents
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty {
            content.body = body
        }
        if let soundName {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(soundName))
        } else {
            content.sound = .default
        }
        if let categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        content.interruptionLevel = interruptionLevel
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancelRequests(identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

#if DEBUG
struct PreviewNotificationCenter: NotificationCenterAdapter {
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func schedule(
        identifier: String,
        title: String,
        body: String,
        soundName: String?,
        categoryIdentifier: String?,
        interruptionLevel: UNNotificationInterruptionLevel,
        components: DateComponents
    ) async throws {}
    func cancelRequests(identifiers: [String]) async {}
}
#endif
