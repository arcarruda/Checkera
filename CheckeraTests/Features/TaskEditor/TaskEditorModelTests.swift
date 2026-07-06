import Foundation
import Testing
@testable import Checkera

@MainActor
@Suite("TaskEditorModel")
struct TaskEditorModelTests {

    // MARK: - Setup

    private func clock(_ year: Int = 2026, _ month: Int = 5, _ day: Int = 5, _ hour: Int = 10, _ minute: Int = 0) -> any Clock {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return FixedClock(Calendar.current.date(from: comps)!)
    }

    private func date(year: Int = 2026, month: Int = 5, day: Int = 5, hour: Int = 9, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    private func makeSettings() -> SettingsModel {
        let suite = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return SettingsModel(defaults: defaults)
    }

    private func makeNotifications(authorized: Bool = true) -> (NotificationService, StubNotificationCenter) {
        let stub = StubNotificationCenter()
        stub.authorizationStatusValue = authorized ? .authorized : .denied
        return (NotificationService(adapter: stub), stub)
    }

    private func makeModel(
        mode: TaskEditorModel.Mode = .add(prefilledStart: nil),
        repository: any TaskRepository = StubTaskRepository(),
        clockNow: (any Clock)? = nil,
        notifications: NotificationService? = nil,
        settings: SettingsModel? = nil
    ) -> TaskEditorModel {
        let (defaultNotifs, _) = makeNotifications()
        return TaskEditorModel(
            mode: mode,
            repository: repository,
            clock: clockNow ?? clock(),
            notifications: notifications ?? defaultNotifs,
            settings: settings ?? makeSettings()
        )
    }

    // MARK: - .add — initial state

    @Test("add mode initializes with empty title")
    func addInitTitle() {
        let model = makeModel()
        #expect(model.title == "")
    }

    @Test("add mode default startDate is the next full hour from the clock")
    func addDefaultStart() {
        let now = clock(2026, 5, 5, 10, 30)
        let model = makeModel(clockNow: now)
        let cal = Calendar.current
        #expect(cal.component(.hour, from: model.startDate) == 11)
        #expect(cal.component(.minute, from: model.startDate) == 0)
    }

    @Test("add mode honors prefilledStart")
    func addPrefilled() {
        let prefilled = date(hour: 14, minute: 0)
        let model = makeModel(mode: .add(prefilledStart: prefilled))
        #expect(model.startDate == prefilled)
    }

    @Test("add mode with a today-aligned prefilledStart sets taskDay to today")
    func addPrefilledTodayDay() {
        let now = clock(2026, 5, 5, 10, 0)
        let prefilled = date(year: 2026, month: 5, day: 5, hour: 11, minute: 0)
        let model = makeModel(mode: .add(prefilledStart: prefilled), clockNow: now)
        #expect(model.taskDay == .today)
    }

    @Test("add mode default duration is 30 minutes")
    func addDefaultDuration() {
        let model = makeModel()
        #expect(model.durationMinutes == 30)
    }

    @Test("add mode default type is regular")
    func addDefaultType() {
        let model = makeModel()
        #expect(model.type == .regular)
    }

    @Test("add mode isEditing is false")
    func addIsEditingFalse() {
        let model = makeModel()
        #expect(model.isEditing == false)
    }

    // MARK: - .edit — initial state

    @Test("edit mode populates fields from repository")
    func editPopulatesFields() {
        let repo = StubTaskRepository()
        let task = DailyTask(
            title: "Existing",
            details: "notes",
            startDate: date(hour: 14),
            durationMinutes: 60,
            type: .golden
        )
        let day = Calendar.current.startOfDay(for: task.startDate)
        repo.tasksByDate[day] = [task]

        let model = makeModel(mode: .edit(taskID: task.id), repository: repo)

        #expect(model.title == "Existing")
        #expect(model.details == "notes")
        #expect(model.startDate == task.startDate)
        #expect(model.durationMinutes == 60)
        #expect(model.type == .golden)
    }

    @Test("edit mode isEditing is true")
    func editIsEditingTrue() {
        let model = makeModel(mode: .edit(taskID: UUID()))
        #expect(model.isEditing == true)
    }

    // MARK: - canSave

    @Test("canSave is false for empty title")
    func canSaveFalseForEmpty() {
        let model = makeModel()
        #expect(model.canSave == false)
    }

    @Test("canSave is false for whitespace-only title")
    func canSaveFalseForWhitespace() {
        let model = makeModel()
        model.title = "   \n\t  "
        #expect(model.canSave == false)
    }

    @Test("canSave is true for non-empty title")
    func canSaveTrueForNonEmpty() {
        let model = makeModel()
        model.title = "Hello"
        #expect(model.canSave == true)
    }

    // MARK: - endDate

    @Test("setting endDate back-derives durationMinutes")
    func endDateSetterDerivesDuration() {
        let model = makeModel()
        let start = model.startDate
        model.endDate = start.addingTimeInterval(45 * 60)
        #expect(model.durationMinutes == 45)
    }

    @Test("setting endDate flags manual edit")
    func endDateSetterFlags() {
        let model = makeModel()
        #expect(model.endTimeWasManuallyEdited == false)
        model.endDate = model.startDate.addingTimeInterval(60 * 60)
        #expect(model.endTimeWasManuallyEdited == true)
    }

    @Test("endDate exactly at startDate clamps to a minimum of 15 minutes")
    func endDateAtStart() {
        let model = makeModel()
        model.endDate = model.startDate
        #expect(model.durationMinutes == 15)
    }

    @Test("endDate set 1 hour before start is reinterpreted as 23 hours after (cross-midnight)")
    func endDateBeforeStartIsNextDay() {
        let model = makeModel()
        model.endDate = model.startDate.addingTimeInterval(-3600)
        #expect(model.durationMinutes == 23 * 60)
    }

    @Test("endDate caps duration at 24 hours minus 1 minute")
    func endDateCapsAt24Hours() {
        let model = makeModel()
        model.endDate = model.startDate.addingTimeInterval(48 * 60 * 60)
        #expect(model.durationMinutes == 24 * 60 - 1)
    }

    @Test("endDate getter equals startDate plus durationMinutes")
    func endDateGetter() {
        let model = makeModel()
        let start = model.startDate
        #expect(model.endDate == start.addingTimeInterval(TimeInterval(model.durationMinutes * 60)))
    }

    // MARK: - save — happy path

    @Test("save in .add mode inserts task via repository")
    func saveAddInserts() async {
        let repo = StubTaskRepository()
        let model = makeModel(repository: repo)
        model.title = "New task"

        let saved = await model.save()

        #expect(saved == true)
        #expect(repo.insertedTasks.count == 1)
        #expect(repo.insertedTasks.first?.title == "New task")
    }

    @Test("save trims whitespace from title")
    func saveTrimsTitle() async {
        let repo = StubTaskRepository()
        let model = makeModel(repository: repo)
        model.title = "  Trimmed  "

        _ = await model.save()

        #expect(repo.insertedTasks.first?.title == "Trimmed")
    }

    @Test("save in .edit mode updates the existing task in place")
    func saveEditUpdates() async {
        let repo = StubTaskRepository()
        let task = DailyTask(title: "Old", startDate: date(), durationMinutes: 30)
        let day = Calendar.current.startOfDay(for: task.startDate)
        repo.tasksByDate[day] = [task]

        let model = makeModel(mode: .edit(taskID: task.id), repository: repo)
        model.title = "New"

        let saved = await model.save()

        #expect(saved == true)
        #expect(repo.updatedTasks.count == 1)
        #expect(task.title == "New")
    }

    // MARK: - save — error paths

    @Test("save returns false when canSave is false")
    func saveReturnsFalseForInvalid() async {
        let model = makeModel()
        let saved = await model.save()
        #expect(saved == false)
    }

    @Test("save sets saveError when repository throws")
    func saveSetsErrorOnFailure() async {
        let repo = StubTaskRepository()
        repo.shouldThrow = true
        let model = makeModel(repository: repo)
        model.title = "New"

        let saved = await model.save()

        #expect(saved == false)
        #expect(model.saveError != nil)
    }

    // MARK: - save — notifications

    @Test("save schedules notification for future tasks when authorized")
    func saveSchedulesWhenAuthorized() async {
        let (notifications, stub) = makeNotifications(authorized: true)
        let repo = StubTaskRepository()
        let now = clock(2026, 5, 5, 10, 0)
        let model = makeModel(repository: repo, clockNow: now, notifications: notifications)
        model.title = "Future task"
        model.startDate = date(hour: 14, minute: 0)

        _ = await model.save()

        #expect(stub.scheduledRequests.count == 1)
        #expect(stub.scheduledRequests.first?.title == "Future task")
    }

    @Test("save does not schedule when authorization denied")
    func saveNoScheduleWhenDenied() async {
        let (notifications, stub) = makeNotifications(authorized: false)
        stub.authorizationStatusValue = .denied
        let model = makeModel(notifications: notifications)
        model.title = "x"

        _ = await model.save()

        #expect(stub.scheduledRequests.isEmpty)
    }

    @Test("save in .edit mode reschedules notification (cancel + schedule)")
    func saveReschedulesOnEdit() async {
        let (notifications, stub) = makeNotifications(authorized: true)
        let repo = StubTaskRepository()
        let now = clock(2026, 5, 5, 10, 0)
        let task = DailyTask(title: "old", startDate: date(hour: 16, minute: 0))
        repo.tasksByDate[Calendar.current.startOfDay(for: task.startDate)] = [task]

        let model = makeModel(
            mode: .edit(taskID: task.id),
            repository: repo,
            clockNow: now,
            notifications: notifications
        )
        model.title = "new"

        _ = await model.save()

        #expect(stub.canceledIdentifiers.contains(task.id.uuidString))
        #expect(stub.scheduledRequests.count == 1)
    }

    // MARK: - delete

    @Test("delete removes the task and cancels its notification")
    func deleteRemovesTaskAndCancels() async {
        let (notifications, stub) = makeNotifications()
        let repo = StubTaskRepository()
        let task = DailyTask(title: "x", startDate: date(hour: 14))
        repo.tasksByDate[Calendar.current.startOfDay(for: task.startDate)] = [task]

        let model = makeModel(
            mode: .edit(taskID: task.id),
            repository: repo,
            notifications: notifications
        )

        let deleted = await model.delete()

        #expect(deleted == true)
        #expect(repo.deletedTasks.count == 1)
        #expect(stub.canceledIdentifiers.contains(task.id.uuidString))
    }

    @Test("delete returns false in .add mode")
    func deleteFalseInAddMode() async {
        let model = makeModel()
        let deleted = await model.delete()
        #expect(deleted == false)
    }
}
