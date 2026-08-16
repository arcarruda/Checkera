import Foundation
import os
import SwiftUI

@MainActor
@Observable
final class HomeModel {

    // MARK: - State

    var selectedDay: Day = .today
    private(set) var tasksByDay: [Day: [DailyTask]] = [:]

    // MARK: - Dependencies

    private let clock: any Clock
    private let repository: any TaskRepository
    private let notifications: NotificationService?
    private let settings: SettingsModel?
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

    /// Moves a task to a new time on the same day, preserving its duration.
    ///
    /// Deliberately synchronous: `repository.update` is synchronous and `DailyTask` is a `@Model`
    /// reference type SwiftUI observes directly, so callers can clear a drag offset in the same
    /// transaction as the write and the row never renders at its old position. The notification
    /// reschedule is fired off the render path.
    ///
    /// Returns the reschedule task so tests can await it; callers in the view ignore it.
    @discardableResult
    func moveTask(_ task: DailyTask, toMinuteOfDay minute: Int, on day: Day) -> Task<Void, Never>? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date(for: day))
        guard let newStart = calendar.date(byAdding: .minute, value: minute, to: dayStart),
              newStart != task.startDate else { return nil }
        do {
            try repository.update(task) { existing in
                existing.startDate = newStart
            }
            return Task { await self.rescheduleNotification(for: task) }
        } catch {
            logger.error("moveTask failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// Mirrors `TaskEditorModel.rescheduleNotification(for:)`. Must run *after* the repository
    /// write — `reschedule` reads `startDate` off the live model object.
    private func rescheduleNotification(for task: DailyTask) async {
        guard let notifications, let settings else { return }
        if await notifications.requestAuthorizationIfNeeded() {
            await notifications.reschedule(task, tone: settings.tone(for: task.color), now: clock.now)
        } else {
            await notifications.cancel(id: task.id)
        }
    }

    // MARK: - Layout

    static let hourHeight: CGFloat = 64
    static let leadingGutter: CGFloat = 56
    static let pointsPerMinute: CGFloat = hourHeight / 60

    /// Granularity a dragged task snaps to. Matches the app's 15-minute convention
    /// (`MinuteIntervalTimePicker.minuteInterval`, `TaskEditorModel.presetDurations`).
    static let dragSnapMinutes = 15

    static func minuteOfDay(_ date: Date, in calendar: Calendar = .current) -> Int {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    /// Resolves a drag into a new start minute-of-day.
    ///
    /// Takes a *delta* in points rather than an absolute Y so that scroll content margins, safe-area
    /// insets, and the leading gutter all cancel out — the caller never has to know the content
    /// origin. Rounds to the nearest snap step (dragging a block reads better with nearest, unlike
    /// tap-to-create which floors into the tapped quarter-hour) and clamps so the whole task stays
    /// inside the day, keeping it within both the 24h canvas and its `[startOfDay, +1d)` day query.
    static func dropMinute(baselineMinute: Int, deltaPoints: CGFloat, durationMinutes: Int) -> Int {
        let raw = CGFloat(baselineMinute) + deltaPoints / pointsPerMinute
        let snapped = Int((raw / CGFloat(dragSnapMinutes)).rounded()) * dragSnapMinutes
        let upper = max(0, 24 * 60 - max(dragSnapMinutes, durationMinutes))
        return min(max(snapped, 0), upper)
    }

    /// Clamps a continuous drag offset (points) to the same bounds `dropMinute` enforces, so the
    /// card visually stops at 00:00 and at the last slot that keeps the task inside the day
    /// instead of sliding off the canvas.
    static func clampedDragOffset(_ deltaPoints: CGFloat, baselineMinute: Int, durationMinutes: Int) -> CGFloat {
        let upper = max(0, 24 * 60 - max(dragSnapMinutes, durationMinutes))
        let minOffset = CGFloat(0 - baselineMinute) * pointsPerMinute
        let maxOffset = CGFloat(upper - baselineMinute) * pointsPerMinute
        return min(max(deltaPoints, minOffset), maxOffset)
    }

    /// The frame of a placed task on the timeline canvas, in the ZStack's coordinate space.
    /// Single source of truth for row geometry: `DayTimelineView` renders with it and
    /// `TimelineDragController` hit-tests with it, so the two cannot drift apart.
    func frame(for placed: PlacedTask, availableWidth: CGFloat) -> CGRect {
        let usableWidth = max(0, availableWidth - Self.leadingGutter - 16)
        let columnWidth = usableWidth / CGFloat(max(placed.columnCount, 1))
        let x = Self.leadingGutter + 8 + columnWidth * CGFloat(placed.column)
        let width = max(0, columnWidth - 4)
        let y = yOffset(for: placed.task.startDate)
        let height = max(40, CGFloat(placed.task.durationMinutes) * Self.pointsPerMinute - 4)
        return CGRect(x: x, y: y, width: width, height: height)
    }

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
