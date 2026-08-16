import Foundation
import os

@MainActor
@Observable
final class TaskEditorModel {

    // MARK: - Mode

    enum Mode: Equatable {
        case add(prefilledStart: Date?)
        case edit(taskID: UUID)
    }

    // MARK: - Form fields

    var title: String
    var details: String
    var startDate: Date
    var durationMinutes: Int
    var endTimeWasManuallyEdited: Bool
    var color: TaskColor
    var taskDay: Day

    // MARK: - State

    private(set) var isSaving: Bool = false
    private(set) var saveError: String?
    private(set) var loadFailed: Bool = false

    // MARK: - Dependencies

    let mode: Mode
    private let repository: any TaskRepository
    private let clock: any Clock
    private let notifications: NotificationService
    private let settings: SettingsModel
    private let logger = Logger(subsystem: "app.checkera", category: "TaskEditor")

    private var editingTask: DailyTask?

    // MARK: - Init

    init(
        mode: Mode,
        repository: any TaskRepository,
        clock: any Clock,
        notifications: NotificationService,
        settings: SettingsModel
    ) {
        self.mode = mode
        self.repository = repository
        self.clock = clock
        self.notifications = notifications
        self.settings = settings

        switch mode {
        case .add(let prefilled):
            let start = prefilled ?? Self.defaultStartDate(from: clock)
            self.title = ""
            self.details = ""
            self.startDate = start
            self.durationMinutes = 30
            self.endTimeWasManuallyEdited = false
            self.color = .fallback
            self.taskDay = Self.dayForDate(start, relativeTo: clock.now)
            self.editingTask = nil
        case .edit(let id):
            do {
                if let task = try repository.task(id: id) {
                    self.title = task.title
                    self.details = task.details
                    self.startDate = task.startDate
                    self.durationMinutes = task.durationMinutes
                    self.endTimeWasManuallyEdited = task.endTimeWasManuallyEdited
                    self.color = task.color
                    self.taskDay = Self.dayForDate(task.startDate, relativeTo: clock.now)
                    self.editingTask = task
                } else {
                    self.title = ""
                    self.details = ""
                    self.startDate = clock.now
                    self.durationMinutes = 30
                    self.endTimeWasManuallyEdited = false
                    self.color = .fallback
                    self.taskDay = .today
                    self.editingTask = nil
                    self.loadFailed = true
                }
            } catch {
                self.title = ""
                self.details = ""
                self.startDate = clock.now
                self.durationMinutes = 30
                self.endTimeWasManuallyEdited = false
                self.color = .fallback
                self.taskDay = .today
                self.editingTask = nil
                self.loadFailed = true
            }
        }
    }

    // MARK: - Derived

    var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var endDate: Date {
        get { startDate.addingTimeInterval(TimeInterval(durationMinutes * 60)) }
        set {
            var interval = newValue.timeIntervalSince(startDate)
            if interval < 0 {
                interval += 24 * 60 * 60
            }
            let minutes = max(15, min(24 * 60 - 1, Int(interval / 60)))
            durationMinutes = minutes
            endTimeWasManuallyEdited = true
        }
    }

    var canSave: Bool {
        guard !loadFailed else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Statics

    static let presetDurations: [Int] = Array(stride(from: 15, through: 600, by: 15))

    static func dayForDate(_ date: Date, relativeTo now: Date, calendar: Calendar = .current) -> Day {
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return calendar.isDate(date, inSameDayAs: startOfTomorrow) ? .tomorrow : .today
    }

    static func defaultStartDate(from clock: any Clock) -> Date {
        let now = clock.now
        let cal = Calendar.current
        let hour = cal.component(.hour, from: now)
        let nextHour = hour < 23 ? hour + 1 : 23
        return cal.date(bySettingHour: nextHour, minute: 0, second: 0, of: now) ?? now
    }

    // MARK: - Actions

    func applyTaskDay(_ day: Day) {
        let cal = Calendar.current
        let base = day.date(relativeTo: clock.now, calendar: cal)
        let comps = cal.dateComponents([.hour, .minute, .second], from: startDate)
        startDate = cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: base) ?? base
    }

    @discardableResult
    func save() async -> Bool {
        guard canSave else { return false }
        isSaving = true
        defer { isSaving = false }

        do {
            switch mode {
            case .add:
                let task = DailyTask(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    details: details,
                    startDate: startDate,
                    durationMinutes: durationMinutes,
                    endTimeWasManuallyEdited: endTimeWasManuallyEdited,
                    color: color
                )
                try repository.insert(task)
                editingTask = task
                await scheduleNotification(for: task)
            case .edit:
                guard let task = editingTask else {
                    saveError = String(localized: "Couldn't find this task to update.", comment: "Error shown when an edited task no longer exists in storage")
                    return false
                }
                try repository.update(task) { existing in
                    existing.title = self.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    existing.details = self.details
                    existing.startDate = self.startDate
                    existing.durationMinutes = self.durationMinutes
                    existing.endTimeWasManuallyEdited = self.endTimeWasManuallyEdited
                    existing.color = self.color
                }
                await rescheduleNotification(for: task)
            }
            saveError = nil
            return true
        } catch {
            logger.error("save failed: \(String(describing: error), privacy: .public)")
            saveError = String(localized: "Couldn't save the task. Please try again.", comment: "Generic save-error message")
            return false
        }
    }

    @discardableResult
    func delete() async -> Bool {
        guard case .edit = mode, let task = editingTask else { return false }
        do {
            await notifications.cancel(id: task.id)
            try repository.delete(task)
            return true
        } catch {
            logger.error("delete failed: \(String(describing: error), privacy: .public)")
            saveError = String(localized: "Couldn't delete this task.", comment: "Error shown when delete fails")
            return false
        }
    }

    // MARK: - Notification helpers

    private func scheduleNotification(for task: DailyTask) async {
        let granted = await notifications.requestAuthorizationIfNeeded()
        guard granted else { return }
        await notifications.schedule(task, tone: settings.tone(for: task.color), now: clock.now)
    }

    private func rescheduleNotification(for task: DailyTask) async {
        let granted = await notifications.requestAuthorizationIfNeeded()
        if granted {
            await notifications.reschedule(task, tone: settings.tone(for: task.color), now: clock.now)
        } else {
            await notifications.cancel(id: task.id)
        }
    }
}
