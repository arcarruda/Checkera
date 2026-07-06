import Foundation
import UserNotifications
import Testing
@testable import Checkera

@MainActor
@Suite("NotificationService")
struct NotificationServiceTests {

    private func date(year: Int = 2026, month: Int = 6, day: Int = 1, hour: Int = 14, minute: Int = 30) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    // MARK: - schedule — happy path

    @Test("schedule builds a request with the task's identifier and time range as title")
    func scheduleBuildsRequest() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let target = date(hour: 14, minute: 30)
        let now = target.addingTimeInterval(-3600)
        let task = DailyTask(title: "Run", startDate: target)

        await service.schedule(task, tone: .regularDefault, now: now)

        let expectedTitle = "\(target.formatted(.dateTime.hour().minute())) - \(task.endDate.formatted(.dateTime.hour().minute()))"
        #expect(stub.scheduledRequests.count == 1)
        #expect(stub.scheduledRequests.first?.identifier == task.id.uuidString)
        #expect(stub.scheduledRequests.first?.title == expectedTitle)
    }

    @Test("scheduled trigger components match the task's start date")
    func scheduleTriggerComponents() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let target = date(year: 2026, month: 6, day: 1, hour: 14, minute: 30)
        let now = target.addingTimeInterval(-3600)
        let task = DailyTask(title: "x", startDate: target)

        await service.schedule(task, tone: .regularDefault, now: now)

        let comps = stub.scheduledRequests.first!.components
        #expect(comps.year == 2026)
        #expect(comps.month == 6)
        #expect(comps.day == 1)
        #expect(comps.hour == 14)
        #expect(comps.minute == 30)
    }

    @Test("schedule sets the body to 'Time for <title>' and ignores task details")
    func schedulePassesBody() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let target = date()
        let now = target.addingTimeInterval(-3600)
        let task = DailyTask(title: "Run", details: "Important details", startDate: target)

        await service.schedule(task, tone: .regularDefault, now: now)

        #expect(stub.scheduledRequests.first?.body == "Time for Run")
    }

    // MARK: - schedule — past trigger

    @Test("schedule skips tasks whose start time has already passed")
    func scheduleSkipsPast() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let now = date()
        let task = DailyTask(title: "x", startDate: now.addingTimeInterval(-100))

        await service.schedule(task, tone: .regularDefault, now: now)

        #expect(stub.scheduledRequests.isEmpty)
    }

    @Test("schedule skips tasks whose start time equals now")
    func scheduleSkipsExactlyNow() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let now = date()
        let task = DailyTask(title: "x", startDate: now)

        await service.schedule(task, tone: .regularDefault, now: now)

        #expect(stub.scheduledRequests.isEmpty)
    }

    // MARK: - schedule — non-today

    @Test("schedule skips tasks scheduled for tomorrow")
    func scheduleSkipsTomorrow() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let now = date(year: 2026, month: 6, day: 1, hour: 9, minute: 0)
        let tomorrow = date(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let task = DailyTask(title: "x", startDate: tomorrow)

        await service.schedule(task, tone: .regularDefault, now: now)

        #expect(stub.scheduledRequests.isEmpty)
    }

    @Test("schedule skips tasks scheduled for yesterday")
    func scheduleSkipsYesterday() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let now = date(year: 2026, month: 6, day: 2, hour: 9, minute: 0)
        let yesterday = date(year: 2026, month: 6, day: 1, hour: 9, minute: 0)
        let task = DailyTask(title: "x", startDate: yesterday)

        await service.schedule(task, tone: .regularDefault, now: now)

        #expect(stub.scheduledRequests.isEmpty)
    }

    // MARK: - cancel

    @Test("cancel removes pending requests matching the task id")
    func cancelRemovesByID() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let target = date()
        let task = DailyTask(title: "x", startDate: target)
        let now = target.addingTimeInterval(-3600)
        await service.schedule(task, tone: .regularDefault, now: now)

        await service.cancel(id: task.id)

        #expect(stub.canceledIdentifiers.contains(task.id.uuidString))
        #expect(stub.scheduledRequests.isEmpty)
    }

    // MARK: - reschedule

    @Test("reschedule cancels the old id then schedules the new request")
    func rescheduleCancelsAndSchedules() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let target = date()
        let now = target.addingTimeInterval(-3600)
        let task = DailyTask(title: "x", startDate: target)

        await service.reschedule(task, tone: .regularDefault, now: now)

        #expect(stub.canceledIdentifiers.contains(task.id.uuidString))
        #expect(stub.scheduledRequests.count == 1)
    }

    // MARK: - authorization

    @Test("requestAuthorizationIfNeeded returns true when already authorized")
    func authIfNeededAlreadyAuthorized() async {
        let stub = StubNotificationCenter()
        stub.authorizationStatusValue = .authorized
        let service = NotificationService(adapter: stub)

        let granted = await service.requestAuthorizationIfNeeded()

        #expect(granted == true)
    }

    @Test("requestAuthorizationIfNeeded requests when notDetermined and grants")
    func authIfNeededNotDeterminedGrants() async {
        let stub = StubNotificationCenter()
        stub.authorizationStatusValue = .notDetermined
        stub.authorizationGranted = true
        let service = NotificationService(adapter: stub)

        let granted = await service.requestAuthorizationIfNeeded()

        #expect(granted == true)
        #expect(stub.authorizationStatusValue == .authorized)
    }

    @Test("requestAuthorizationIfNeeded returns false when denied")
    func authIfNeededDenied() async {
        let stub = StubNotificationCenter()
        stub.authorizationStatusValue = .denied
        let service = NotificationService(adapter: stub)

        let granted = await service.requestAuthorizationIfNeeded()

        #expect(granted == false)
    }

    @Test("requestAuthorizationIfNeeded returns false when adapter throws")
    func authIfNeededThrows() async {
        let stub = StubNotificationCenter()
        stub.authorizationStatusValue = .notDetermined
        stub.shouldThrowOnAuth = true
        let service = NotificationService(adapter: stub)

        let granted = await service.requestAuthorizationIfNeeded()

        #expect(granted == false)
    }

    // MARK: - schedule — golden vs regular

    @Test("golden task uses the goldenAlarm category and time-sensitive interruption")
    func scheduleGoldenAlarmCategory() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let target = date()
        let now = target.addingTimeInterval(-3600)
        let task = DailyTask(title: "Deep work", startDate: target, type: .golden)

        await service.schedule(task, tone: .goldenBell, now: now)

        #expect(stub.scheduledRequests.first?.categoryIdentifier == NotificationCategoryID.goldenAlarm)
        #expect(stub.scheduledRequests.first?.interruptionLevel == .timeSensitive)
    }

    @Test("regular task uses the regular category and active interruption")
    func scheduleRegularCategory() async {
        let stub = StubNotificationCenter()
        let service = NotificationService(adapter: stub)
        let target = date()
        let now = target.addingTimeInterval(-3600)
        let task = DailyTask(title: "Run", startDate: target, type: .regular)

        await service.schedule(task, tone: .regularDefault, now: now)

        #expect(stub.scheduledRequests.first?.categoryIdentifier == NotificationCategoryID.regular)
        #expect(stub.scheduledRequests.first?.interruptionLevel == .active)
    }
}
