import Foundation
import UserNotifications
import os

struct SnoozeScheduler: Sendable {

    let interval: TimeInterval
    let add: @Sendable (UNNotificationRequest) async throws -> Void

    func snooze(content: UNNotificationContent, identifier: String) async throws {
        let mutable = (content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: mutable, trigger: trigger)
        try await add(request)
    }

    static func live(interval: TimeInterval = 15 * 60) -> SnoozeScheduler {
        SnoozeScheduler(
            interval: interval,
            add: { try await UNUserNotificationCenter.current().add($0) }
        )
    }
}

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    private let scheduler: SnoozeScheduler
    private let logger = Logger(subsystem: "app.checkera", category: "NotificationDelegate")

    init(scheduler: SnoozeScheduler = .live()) {
        self.scheduler = scheduler
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await handle(
            actionIdentifier: response.actionIdentifier,
            content: response.notification.request.content,
            identifier: response.notification.request.identifier
        )
    }

    func handle(actionIdentifier: String, content: UNNotificationContent, identifier: String) async {
        switch actionIdentifier {
        case NotificationActionID.snooze15:
            do {
                try await scheduler.snooze(content: content, identifier: identifier)
            } catch {
                logger.error("snooze failed: \(String(describing: error), privacy: .public)")
            }
        default:
            return
        }
    }
}
