import Foundation
import UserNotifications
import Testing
@testable import Checkera

@Suite("NotificationDelegate")
struct NotificationDelegateTests {

    private actor RequestRecorder {
        var requests: [UNNotificationRequest] = []
        func record(_ request: UNNotificationRequest) { requests.append(request) }
    }

    private func makeContent(
        title: String = "10:00 - 10:30",
        body: String = "Time for Deep work",
        category: String = NotificationCategoryID.goldenAlarm,
        level: UNNotificationInterruptionLevel = .timeSensitive
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category
        content.interruptionLevel = level
        return content
    }

    private func makeDelegate(
        interval: TimeInterval = 900,
        recorder: RequestRecorder
    ) -> NotificationDelegate {
        let scheduler = SnoozeScheduler(
            interval: interval,
            add: { request in await recorder.record(request) }
        )
        return NotificationDelegate(scheduler: scheduler)
    }

    // MARK: - SnoozeScheduler — happy path

    @Test("snooze creates a request with the original identifier")
    func snoozeKeepsIdentifier() async throws {
        let recorder = RequestRecorder()
        let scheduler = SnoozeScheduler(
            interval: 900,
            add: { request in await recorder.record(request) }
        )

        try await scheduler.snooze(content: makeContent(), identifier: "task-abc")

        let requests = await recorder.requests
        #expect(requests.first?.identifier == "task-abc")
    }

    @Test("snooze schedules with a 15-minute interval trigger")
    func snoozeUsesInterval() async throws {
        let recorder = RequestRecorder()
        let scheduler = SnoozeScheduler(
            interval: 900,
            add: { request in await recorder.record(request) }
        )

        try await scheduler.snooze(content: makeContent(), identifier: "x")

        let requests = await recorder.requests
        let trigger = requests.first?.trigger as? UNTimeIntervalNotificationTrigger
        #expect(trigger?.timeInterval == 900)
        #expect(trigger?.repeats == false)
    }

    @Test("snooze preserves the original content fields")
    func snoozePreservesContent() async throws {
        let recorder = RequestRecorder()
        let scheduler = SnoozeScheduler(
            interval: 900,
            add: { request in await recorder.record(request) }
        )
        let content = makeContent(
            title: "12:00 - 12:30",
            body: "Time for Lunch",
            category: NotificationCategoryID.goldenAlarm,
            level: .timeSensitive
        )

        try await scheduler.snooze(content: content, identifier: "x")

        let requests = await recorder.requests
        let scheduled = requests.first?.content
        #expect(scheduled?.title == "12:00 - 12:30")
        #expect(scheduled?.body == "Time for Lunch")
        #expect(scheduled?.categoryIdentifier == NotificationCategoryID.goldenAlarm)
        #expect(scheduled?.interruptionLevel == .timeSensitive)
    }

    // MARK: - NotificationDelegate.handle — action routing

    @Test("snooze action triggers a new scheduled request")
    func handleSnoozeSchedules() async {
        let recorder = RequestRecorder()
        let delegate = makeDelegate(recorder: recorder)

        await delegate.handle(
            actionIdentifier: NotificationActionID.snooze15,
            content: makeContent(),
            identifier: "task-1"
        )

        let count = await recorder.requests.count
        #expect(count == 1)
    }

    @Test("dismiss action does not schedule a new request")
    func handleDismissDoesNothing() async {
        let recorder = RequestRecorder()
        let delegate = makeDelegate(recorder: recorder)

        await delegate.handle(
            actionIdentifier: NotificationActionID.dismiss,
            content: makeContent(),
            identifier: "task-1"
        )

        let count = await recorder.requests.count
        #expect(count == 0)
    }

    @Test("default tap action does not schedule a new request")
    func handleDefaultActionDoesNothing() async {
        let recorder = RequestRecorder()
        let delegate = makeDelegate(recorder: recorder)

        await delegate.handle(
            actionIdentifier: UNNotificationDefaultActionIdentifier,
            content: makeContent(),
            identifier: "task-1"
        )

        let count = await recorder.requests.count
        #expect(count == 0)
    }

    @Test("system dismiss action does not schedule a new request")
    func handleSystemDismissDoesNothing() async {
        let recorder = RequestRecorder()
        let delegate = makeDelegate(recorder: recorder)

        await delegate.handle(
            actionIdentifier: UNNotificationDismissActionIdentifier,
            content: makeContent(),
            identifier: "task-1"
        )

        let count = await recorder.requests.count
        #expect(count == 0)
    }

    @Test("unknown action identifier is ignored")
    func handleUnknownActionDoesNothing() async {
        let recorder = RequestRecorder()
        let delegate = makeDelegate(recorder: recorder)

        await delegate.handle(
            actionIdentifier: "SOME_OTHER_ACTION",
            content: makeContent(),
            identifier: "task-1"
        )

        let count = await recorder.requests.count
        #expect(count == 0)
    }
}
