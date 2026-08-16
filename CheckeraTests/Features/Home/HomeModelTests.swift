import Foundation
import Testing
@testable import Checkera

@MainActor
@Suite("HomeModel")
struct HomeModelTests {

    // MARK: - Setup

    private func date(year: Int = 2026, month: Int = 5, day: Int = 5, hour: Int = 12, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    private func makeModel(
        now: Date? = nil,
        repository: any TaskRepository = StubTaskRepository(),
        notifications: NotificationService? = nil,
        settings: SettingsModel? = nil
    ) -> HomeModel {
        HomeModel(
            clock: FixedClock(now ?? date()),
            repository: repository,
            notifications: notifications,
            settings: settings
        )
    }

    /// `HomeModel` only reschedules when it has *both* a notification service and settings, so
    /// reschedule assertions need a real (isolated) settings store or they pass against a no-op.
    private func makeSettings() -> SettingsModel {
        let suite = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SettingsModel(defaults: defaults)
    }

    private func makeNotifications(authorized: Bool = true) -> (NotificationService, StubNotificationCenter) {
        let stub = StubNotificationCenter()
        stub.authorizationGranted = authorized
        stub.authorizationStatusValue = authorized ? .authorized : .denied
        return (NotificationService(adapter: stub), stub)
    }

    // MARK: - Defaults

    @Test("default selectedDay is today")
    func defaultSelectedDay() {
        let model = makeModel()
        #expect(model.selectedDay == .today)
    }

    @Test("tasksByDay is empty initially", arguments: Day.allCases)
    func tasksByDayEmpty(_ day: Day) {
        let model = makeModel()
        #expect(model.tasks(for: day).isEmpty)
    }

    // MARK: - selectDay

    @Test("selectDay updates state", arguments: Day.allCases)
    func selectDayUpdates(_ day: Day) {
        let model = makeModel()
        model.selectDay(day)
        #expect(model.selectedDay == day)
    }

    // MARK: - date(for:)

    @Test("date(for: today) returns startOfDay matching clock")
    func dateForToday() {
        let now = date(hour: 14, minute: 30)
        let model = makeModel(now: now)
        #expect(model.date(for: .today) == Calendar.current.startOfDay(for: now))
    }

    @Test("date(for: yesterday) is one day before today")
    func dateForYesterday() {
        let model = makeModel()
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: model.date(for: .yesterday), to: model.date(for: .today))
        #expect(diff.day == 1)
    }

    @Test("date(for: tomorrow) is one day after today")
    func dateForTomorrow() {
        let model = makeModel()
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: model.date(for: .today), to: model.date(for: .tomorrow))
        #expect(diff.day == 1)
    }

    // MARK: - canMarkStatus

    @Test("canMarkStatus is true for yesterday")
    func canMarkYesterday() {
        let model = makeModel()
        let task = DailyTask(title: "x", startDate: date(hour: 14))
        #expect(model.canMarkStatus(task, on: .yesterday) == true)
    }

    @Test("canMarkStatus is true for today's past tasks")
    func canMarkTodayPast() {
        let now = date(hour: 15)
        let model = makeModel(now: now)
        let task = DailyTask(title: "x", startDate: date(hour: 9))
        #expect(model.canMarkStatus(task, on: .today) == true)
    }

    @Test("canMarkStatus is false for today's future tasks")
    func canMarkTodayFuture() {
        let now = date(hour: 9)
        let model = makeModel(now: now)
        let task = DailyTask(title: "x", startDate: date(hour: 18))
        #expect(model.canMarkStatus(task, on: .today) == false)
    }

    @Test("canMarkStatus is false for tomorrow")
    func canMarkTomorrow() {
        let model = makeModel()
        let task = DailyTask(title: "x", startDate: date(hour: 14))
        #expect(model.canMarkStatus(task, on: .tomorrow) == false)
    }

    // MARK: - loadTasks — happy path

    @Test("loadTasks populates tasksByDay from repository")
    func loadTasksPopulates() async {
        let stub = StubTaskRepository()
        let now = date()
        let task = DailyTask(title: "x", startDate: now)
        stub.tasksByDate[Calendar.current.startOfDay(for: now)] = [task]

        let model = makeModel(now: now, repository: stub)
        await model.loadTasks(for: .today)

        #expect(model.tasks(for: .today).count == 1)
        #expect(model.tasks(for: .today).first?.id == task.id)
    }

    @Test("loadTasks for one day does not affect other days")
    func loadTasksScopedToDay() async {
        let stub = StubTaskRepository()
        let now = date()
        stub.tasksByDate[Calendar.current.startOfDay(for: now)] = [DailyTask(title: "today", startDate: now)]

        let model = makeModel(now: now, repository: stub)
        await model.loadTasks(for: .today)

        #expect(model.tasks(for: .today).count == 1)
        #expect(model.tasks(for: .yesterday).isEmpty)
        #expect(model.tasks(for: .tomorrow).isEmpty)
    }

    // MARK: - loadTasks — error paths

    @Test("loadTasks sets empty array when repository throws")
    func loadTasksEmptyOnError() async {
        let stub = StubTaskRepository()
        stub.shouldThrow = true
        let model = makeModel(repository: stub)

        await model.loadTasks(for: .today)

        #expect(model.tasks(for: .today).isEmpty)
    }

    // MARK: - loadAllDays

    @Test("loadAllDays populates tasks for all three days")
    func loadAllDaysPopulatesAll() async {
        let stub = StubTaskRepository()
        let now = date()
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!
        let tomorrowStart = cal.date(byAdding: .day, value: 1, to: todayStart)!

        stub.tasksByDate[yesterdayStart] = [DailyTask(title: "y", startDate: yesterdayStart)]
        stub.tasksByDate[todayStart] = [DailyTask(title: "t", startDate: todayStart)]
        stub.tasksByDate[tomorrowStart] = [DailyTask(title: "tm", startDate: tomorrowStart)]

        let model = makeModel(now: now, repository: stub)
        await model.loadAllDays()

        #expect(model.tasks(for: .yesterday).count == 1)
        #expect(model.tasks(for: .today).count == 1)
        #expect(model.tasks(for: .tomorrow).count == 1)
    }

    // MARK: - setStatus

    @Test("setStatus calls repository.update with new status")
    func setStatusUpdatesRepo() async {
        let stub = StubTaskRepository()
        let task = DailyTask(title: "x", startDate: date())
        let model = makeModel(repository: stub)

        await model.setStatus(.accomplished, on: task)

        #expect(stub.updatedTasks.count == 1)
        #expect(task.status == .accomplished)
    }

    @Test("setStatus reloads selectedDay tasks after update")
    func setStatusReloadsSelectedDay() async {
        let stub = StubTaskRepository()
        let now = date()
        let dayStart = Calendar.current.startOfDay(for: now)
        stub.tasksByDate[dayStart] = []

        let model = makeModel(now: now, repository: stub)
        model.selectDay(.today)
        let task = DailyTask(title: "x", startDate: now)

        await model.setStatus(.lateAccomplished, on: task)

        #expect(model.tasks(for: .today).isEmpty)
    }

    // MARK: - deleteTask

    @Test("deleteTask calls repository.delete with the task")
    func deleteTaskCallsRepo() async {
        let stub = StubTaskRepository()
        let task = DailyTask(title: "x", startDate: date())
        let model = makeModel(repository: stub)

        await model.deleteTask(task)

        #expect(stub.deletedTasks.count == 1)
        #expect(stub.deletedTasks.first?.id == task.id)
    }

    @Test("deleteTask reloads selectedDay tasks after delete")
    func deleteTaskReloadsSelectedDay() async {
        let stub = StubTaskRepository()
        let now = date()
        let dayStart = Calendar.current.startOfDay(for: now)
        stub.tasksByDate[dayStart] = []

        let model = makeModel(now: now, repository: stub)
        model.selectDay(.today)
        let task = DailyTask(title: "x", startDate: now)

        await model.deleteTask(task)

        #expect(model.tasks(for: .today).isEmpty)
    }

    @Test("deleteTask swallows repository errors")
    func deleteTaskSwallowsErrors() async {
        let stub = StubTaskRepository()
        stub.shouldThrow = true
        let model = makeModel(repository: stub)

        await model.deleteTask(DailyTask(title: "x", startDate: date()))
    }

    @Test("deleteTask cancels the notification before deleting")
    func deleteTaskCancelsNotification() async {
        let stub = StubTaskRepository()
        let notifStub = StubNotificationCenter()
        let notifications = NotificationService(adapter: notifStub)
        let task = DailyTask(title: "x", startDate: date())
        let model = makeModel(repository: stub, notifications: notifications)

        await model.deleteTask(task)

        #expect(notifStub.canceledIdentifiers.contains(task.id.uuidString))
        #expect(stub.deletedTasks.first?.id == task.id)
    }

    // MARK: - moveTask

    @Test("moveTask writes the new start date, preserving duration")
    func moveTaskWritesStartDate() async {
        let repo = StubTaskRepository()
        let now = date(hour: 10)
        let task = DailyTask(title: "x", startDate: date(hour: 9), durationMinutes: 45)
        let model = makeModel(now: now, repository: repo)

        await model.moveTask(task, toMinuteOfDay: 18 * 60 + 30, on: .today)?.value

        #expect(repo.updatedTasks.count == 1)
        #expect(task.startDate == date(hour: 18, minute: 30))
        #expect(task.durationMinutes == 45)
    }

    @Test("moveTask is a no-op when the time is unchanged")
    func moveTaskNoOp() async {
        let repo = StubTaskRepository()
        let task = DailyTask(title: "x", startDate: date(hour: 9))
        let model = makeModel(now: date(hour: 10), repository: repo)

        await model.moveTask(task, toMinuteOfDay: 9 * 60, on: .today)?.value

        #expect(repo.updatedTasks.isEmpty)
    }

    @Test("moveTask reschedules the notification for a future task")
    func moveTaskReschedules() async {
        let repo = StubTaskRepository()
        let (notifications, stub) = makeNotifications()
        let now = date(hour: 10)
        let task = DailyTask(title: "x", startDate: date(hour: 16))
        let model = makeModel(
            now: now,
            repository: repo,
            notifications: notifications,
            settings: makeSettings()
        )

        await model.moveTask(task, toMinuteOfDay: 18 * 60, on: .today)?.value

        #expect(stub.canceledIdentifiers.contains(task.id.uuidString))
        #expect(stub.scheduledRequests.count == 1)
    }

    @Test("moveTask into the past cancels without rescheduling")
    func moveTaskIntoPastCancels() async {
        let repo = StubTaskRepository()
        let (notifications, stub) = makeNotifications()
        let now = date(hour: 14)
        let task = DailyTask(title: "x", startDate: date(hour: 16))
        let model = makeModel(
            now: now,
            repository: repo,
            notifications: notifications,
            settings: makeSettings()
        )

        await model.moveTask(task, toMinuteOfDay: 8 * 60, on: .today)?.value

        #expect(stub.canceledIdentifiers.contains(task.id.uuidString))
        #expect(stub.scheduledRequests.isEmpty)
    }

    @Test("moveTask without notifications or settings still writes")
    func moveTaskWithoutNotificationDependencies() async {
        let repo = StubTaskRepository()
        let task = DailyTask(title: "x", startDate: date(hour: 9))
        let model = makeModel(now: date(hour: 10), repository: repo)

        await model.moveTask(task, toMinuteOfDay: 11 * 60, on: .today)?.value

        #expect(repo.updatedTasks.count == 1)
        #expect(task.startDate == date(hour: 11))
    }

    @Test("moveTask swallows repository errors")
    func moveTaskSwallowsErrors() async {
        let repo = StubTaskRepository()
        repo.shouldThrow = true
        let model = makeModel(repository: repo)

        await model.moveTask(DailyTask(title: "x", startDate: date(hour: 9)), toMinuteOfDay: 600, on: .today)?.value
    }
}
