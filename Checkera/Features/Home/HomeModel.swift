import Foundation
import os
import SwiftUI

@MainActor
@Observable
final class HomeModel {

    // MARK: - State

    var selectedDay: Day = .today
    private(set) var tasksByDay: [Day: [DailyTask]] = [:]
    private(set) var latestPastNonEmptyDay: Date?

    // MARK: - Dependencies

    private let clock: any Clock
    private let repository: any TaskRepository
    private let notifications: NotificationService?
    private let settings: SettingsModel?
    private let dayCopy = DayCopyService()
    private let logger = Logger(subsystem: "app.checkera", category: "Home")

    // MARK: - Init

    init(
        clock: any Clock,
        repository: any TaskRepository,
        notifications: NotificationService? = nil,
        settings: SettingsModel? = nil
    ) {
        self.clock = clock
        self.repository = repository
        self.notifications = notifications
        self.settings = settings
    }

    // MARK: - Derived

    func tasks(for day: Day) -> [DailyTask] {
        tasksByDay[day] ?? []
    }

    func date(for day: Day) -> Date {
        day.date(relativeTo: clock.now)
    }

    func canMarkStatus(_ task: DailyTask, on day: Day) -> Bool {
        switch day {
        case .yesterday: true
        case .today: task.startDate < clock.now
        case .tomorrow: false
        }
    }

    func bringInPlan(for day: Day) -> DayCopyService.BringInPlan? {
        dayCopy.plan(
            for: day,
            targetIsEmpty: tasks(for: day).isEmpty,
            latestPastNonEmptyDay: latestPastNonEmptyDay
        )
    }

    // MARK: - Actions

    func selectDay(_ day: Day) {
        selectedDay = day
    }

    func loadTasks(for day: Day) async {
        do {
            let fetched = try repository.tasks(for: date(for: day))
            tasksByDay[day] = fetched
        } catch {
            logger.error("loadTasks failed for \(day.rawValue, privacy: .public): \(String(describing: error), privacy: .public)")
            tasksByDay[day] = []
        }
    }

    func loadAllDays() async {
        for day in Day.allCases {
            await loadTasks(for: day)
        }
        await loadLatestPastNonEmptyDay()
    }

    private func loadLatestPastNonEmptyDay() async {
        do {
            latestPastNonEmptyDay = try repository.mostRecentNonEmptyDay(
                strictlyBefore: date(for: .tomorrow)
            )
        } catch {
            logger.error("loadLatestPastNonEmptyDay failed: \(String(describing: error), privacy: .public)")
            latestPastNonEmptyDay = nil
        }
    }

    func setStatus(_ status: TaskStatus, on task: DailyTask) async {
        do {
            try repository.update(task) { existing in
                existing.status = status
            }
            await loadTasks(for: selectedDay)
        } catch {
            logger.error("setStatus failed: \(String(describing: error), privacy: .public)")
        }
    }

    func deleteTask(_ task: DailyTask) async {
        do {
            await notifications?.cancel(id: task.id)
            try repository.delete(task)
            await loadTasks(for: selectedDay)
        } catch {
            logger.error("deleteTask failed: \(String(describing: error), privacy: .public)")
        }
    }

    func acceptBringIn(_ plan: DayCopyService.BringInPlan) async {
        let targetDate = date(for: plan.target)
        do {
            let copied = try repository.copyTasks(from: plan.source, to: targetDate)
            await scheduleNotifications(for: copied)
            await loadAllDays()
        } catch {
            logger.error("acceptBringIn failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func scheduleNotifications(for tasks: [DailyTask]) async {
        guard let notifications, let settings, !tasks.isEmpty else { return }
        let granted = await notifications.requestAuthorizationIfNeeded()
        guard granted else { return }
        for task in tasks {
            await notifications.schedule(task, tone: settings.tone(for: task.type), now: clock.now)
        }
    }

    // MARK: - Layout

    static let hourHeight: CGFloat = 64
    static let leadingGutter: CGFloat = 56

    var sleepWindow: SleepWindow {
        settings?.sleepWindow ?? .default
    }

    func yOffset(for date: Date, in calendar: Calendar = .current) -> CGFloat {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return CGFloat((comps.hour ?? 0) * 60 + (comps.minute ?? 0)) * (Self.hourHeight / 60)
    }

    static func layout(_ tasks: [DailyTask]) -> [PlacedTask] {
        guard !tasks.isEmpty else { return [] }
        let sorted = tasks.sorted { $0.startDate < $1.startDate }
        var columnEnds: [Date] = []
        var pairs: [(DailyTask, Int)] = []

        for task in sorted {
            var assigned = false
            for col in 0..<columnEnds.count where columnEnds[col] <= task.startDate {
                columnEnds[col] = task.endDate
                pairs.append((task, col))
                assigned = true
                break
            }
            if !assigned {
                columnEnds.append(task.endDate)
                pairs.append((task, columnEnds.count - 1))
            }
        }

        let columnCount = columnEnds.count
        return pairs.map { PlacedTask(task: $0.0, column: $0.1, columnCount: columnCount) }
    }
}

// MARK: - PlacedTask

struct PlacedTask: Identifiable {
    let task: DailyTask
    let column: Int
    let columnCount: Int
    var id: UUID { task.id }
}

extension PlacedTask: Equatable {
    static func == (lhs: PlacedTask, rhs: PlacedTask) -> Bool {
        lhs.task.id == rhs.task.id
            && lhs.column == rhs.column
            && lhs.columnCount == rhs.columnCount
    }
}
