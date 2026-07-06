import Foundation
import UserNotifications
import os

@MainActor
struct NotificationService {

    let adapter: any NotificationCenterAdapter
    private let logger = Logger(subsystem: "app.checkera", category: "Notifications")

    init(adapter: any NotificationCenterAdapter = LiveNotificationCenter()) {
        self.adapter = adapter
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await adapter.authorizationStatus()
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        let status = await adapter.authorizationStatus()
        switch status {
        case .notDetermined:
            do {
                return try await adapter.requestAuthorization()
            } catch {
                logger.error("requestAuthorization failed: \(String(describing: error), privacy: .public)")
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func schedule(_ task: DailyTask, tone: NotificationTone, now: Date = .now) async {
        guard task.startDate > now else { return }
        guard Calendar.current.isDate(task.startDate, inSameDayAs: now) else { return }
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: task.startDate
        )
        let start = task.startDate.formatted(.dateTime.hour().minute())
        let end = task.endDate.formatted(.dateTime.hour().minute())
        let categoryID: String
        let interruptionLevel: UNNotificationInterruptionLevel
        switch tone.category {
        case .golden:
            categoryID = NotificationCategoryID.goldenAlarm
            interruptionLevel = .timeSensitive
        case .regular:
            categoryID = NotificationCategoryID.regular
            interruptionLevel = .active
        }
        do {
            try await adapter.schedule(
                identifier: task.id.uuidString,
                title: "\(start) - \(end)",
                body: "Time for \(task.title)",
                soundName: Self.soundName(for: tone),
                categoryIdentifier: categoryID,
                interruptionLevel: interruptionLevel,
                components: comps
            )
        } catch {
            logger.error("schedule failed: \(String(describing: error), privacy: .public)")
        }
    }

    func cancel(id: UUID) async {
        await adapter.cancelRequests(identifiers: [id.uuidString])
    }

    func reschedule(_ task: DailyTask, tone: NotificationTone, now: Date = .now) async {
        await cancel(id: task.id)
        await schedule(task, tone: tone, now: now)
    }

    @discardableResult
    func scheduleTestNotification() async -> Bool {
        let granted = await requestAuthorizationIfNeeded()
        guard granted else { return false }
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "Test notification",
            comment: "Title of the test notification scheduled from Settings"
        )
        content.body = String(
            localized: "If you see this, notifications are working.",
            comment: "Body of the test notification scheduled from Settings"
        )
        content.sound = .default
        content.interruptionLevel = .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-notification",
            content: content,
            trigger: trigger
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            logger.error("scheduleTestNotification failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }

    static func soundName(for tone: NotificationTone) -> String? {
        nil
    }
}
