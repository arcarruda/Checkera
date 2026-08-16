import Foundation
import Testing
@testable import Checkera

@MainActor
@Suite("Timeline placement")
struct TimelinePlacementTests {

    // MARK: - Setup

    private func date(hour: Int, minute: Int = 0) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 5
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps)!
    }

    private func makeModel() -> HomeModel {
        HomeModel(clock: FixedClock(date(hour: 12)), repository: StubTaskRepository())
    }

    // MARK: - yOffset

    @Test("yOffset at midnight is zero")
    func yOffsetAtMidnight() {
        let model = makeModel()
        #expect(model.yOffset(for: date(hour: 0)) == 0)
    }

    @Test("yOffset at noon equals 12 * hourHeight")
    func yOffsetAtNoon() {
        let model = makeModel()
        #expect(model.yOffset(for: date(hour: 12)) == 12 * HomeModel.hourHeight)
    }

    @Test("yOffset at 12:30 equals 12.5 * hourHeight")
    func yOffsetAtTwelveThirty() {
        let model = makeModel()
        #expect(model.yOffset(for: date(hour: 12, minute: 30)) == 12.5 * HomeModel.hourHeight)
    }

    @Test("yOffset at 23:59 equals 1439 minutes worth")
    func yOffsetAtEndOfDay() {
        let model = makeModel()
        let expected = CGFloat(23 * 60 + 59) * (HomeModel.hourHeight / 60)
        #expect(model.yOffset(for: date(hour: 23, minute: 59)) == expected)
    }

    // MARK: - minuteOfDay

    @Test("minuteOfDay counts minutes since midnight", arguments: [
        (0, 0, 0), (9, 30, 570), (12, 0, 720), (23, 59, 1439),
    ])
    func minuteOfDayCounts(_ hour: Int, _ minute: Int, _ expected: Int) {
        #expect(HomeModel.minuteOfDay(date(hour: hour, minute: minute)) == expected)
    }

    // MARK: - dropMinute

    @Test("dropMinute with no movement keeps the original time")
    func dropMinuteNoMovement() {
        let result = HomeModel.dropMinute(baselineMinute: 540, deltaPoints: 0, durationMinutes: 60)
        #expect(result == 540)
    }

    @Test("dropMinute converts a whole-hour drag into 60 minutes")
    func dropMinuteWholeHour() {
        let result = HomeModel.dropMinute(
            baselineMinute: 540,
            deltaPoints: HomeModel.hourHeight,
            durationMinutes: 60
        )
        #expect(result == 600)
    }

    @Test("dropMinute drags upward into an earlier time")
    func dropMinuteNegative() {
        let result = HomeModel.dropMinute(
            baselineMinute: 540,
            deltaPoints: -HomeModel.hourHeight,
            durationMinutes: 60
        )
        #expect(result == 480)
    }

    @Test("dropMinute rounds to the nearest 15 minutes, not the floor")
    func dropMinuteRoundsToNearest() {
        // 10 minutes of travel is closer to a 15-minute step than to zero.
        let up = HomeModel.dropMinute(
            baselineMinute: 540,
            deltaPoints: 10 * HomeModel.pointsPerMinute,
            durationMinutes: 60
        )
        #expect(up == 555)

        // 7 minutes is closer to zero.
        let down = HomeModel.dropMinute(
            baselineMinute: 540,
            deltaPoints: 7 * HomeModel.pointsPerMinute,
            durationMinutes: 60
        )
        #expect(down == 540)
    }

    @Test("dropMinute clamps to the start of the day")
    func dropMinuteClampsLower() {
        let result = HomeModel.dropMinute(
            baselineMinute: 60,
            deltaPoints: -10 * HomeModel.hourHeight,
            durationMinutes: 60
        )
        #expect(result == 0)
    }

    @Test("dropMinute clamps so the whole task stays inside the day")
    func dropMinuteClampsUpper() {
        let result = HomeModel.dropMinute(
            baselineMinute: 1200,
            deltaPoints: 10 * HomeModel.hourHeight,
            durationMinutes: 90
        )
        #expect(result == 24 * 60 - 90)   // 22:30, so the 90-minute task ends at midnight
    }

    @Test("dropMinute never clamps a short task tighter than one snap step")
    func dropMinuteShortTaskUpperBound() {
        let result = HomeModel.dropMinute(
            baselineMinute: 1200,
            deltaPoints: 10 * HomeModel.hourHeight,
            durationMinutes: 5
        )
        #expect(result == 24 * 60 - HomeModel.dragSnapMinutes)   // 23:45
    }

    @Test("dropMinute round-trips a yOffset for snap-aligned times", arguments: [0, 15, 30, 45])
    func dropMinuteRoundTrip(_ minute: Int) {
        let model = makeModel()
        let start = date(hour: 9, minute: minute)
        let y = model.yOffset(for: start)
        // Feeding the absolute offset back in as a delta from midnight must recover the same time.
        let result = HomeModel.dropMinute(baselineMinute: 0, deltaPoints: y, durationMinutes: 30)
        #expect(result == HomeModel.minuteOfDay(start))
    }

    // MARK: - clampedDragOffset

    @Test("clampedDragOffset passes through an in-range delta")
    func clampedDragOffsetPassThrough() {
        let result = HomeModel.clampedDragOffset(100, baselineMinute: 540, durationMinutes: 60)
        #expect(result == 100)
    }

    @Test("clampedDragOffset stops the card at midnight going up")
    func clampedDragOffsetLower() {
        let result = HomeModel.clampedDragOffset(-10_000, baselineMinute: 540, durationMinutes: 60)
        #expect(result == CGFloat(-540) * HomeModel.pointsPerMinute)
    }

    @Test("clampedDragOffset stops the card so the task still fits the day going down")
    func clampedDragOffsetUpper() {
        let result = HomeModel.clampedDragOffset(10_000, baselineMinute: 540, durationMinutes: 90)
        let upper = 24 * 60 - 90
        #expect(result == CGFloat(upper - 540) * HomeModel.pointsPerMinute)
    }

    // MARK: - frame(for:availableWidth:)

    @Test("frame places a single-column task across the usable width")
    func frameSingleColumn() {
        let model = makeModel()
        let task = DailyTask(title: "A", startDate: date(hour: 9), durationMinutes: 60)
        let placed = PlacedTask(task: task, column: 0, columnCount: 1)
        let frame = model.frame(for: placed, availableWidth: 400)

        let usable: CGFloat = 400 - HomeModel.leadingGutter - 16
        #expect(frame.minX == HomeModel.leadingGutter + 8)
        #expect(frame.width == usable - 4)
        #expect(frame.minY == 9 * HomeModel.hourHeight)
        #expect(frame.height == CGFloat(60) * HomeModel.pointsPerMinute - 4)
    }

    @Test("frame offsets the second of two columns by the column width")
    func frameSecondColumn() {
        let model = makeModel()
        let task = DailyTask(title: "B", startDate: date(hour: 10), durationMinutes: 30)
        let placed = PlacedTask(task: task, column: 1, columnCount: 2)
        let frame = model.frame(for: placed, availableWidth: 400)

        let usable: CGFloat = 400 - HomeModel.leadingGutter - 16
        let columnWidth = usable / 2
        #expect(frame.minX == HomeModel.leadingGutter + 8 + columnWidth)
        #expect(frame.width == columnWidth - 4)
    }

    @Test("frame enforces the 40pt minimum height for short tasks")
    func frameMinimumHeight() {
        let model = makeModel()
        let task = DailyTask(title: "C", startDate: date(hour: 8), durationMinutes: 15)
        let placed = PlacedTask(task: task, column: 0, columnCount: 1)
        #expect(model.frame(for: placed, availableWidth: 400).height == 40)
    }

    @Test("frame contains a point inside the row and excludes one outside it")
    func frameHitTest() {
        let model = makeModel()
        let task = DailyTask(title: "D", startDate: date(hour: 9), durationMinutes: 60)
        let placed = PlacedTask(task: task, column: 0, columnCount: 1)
        let frame = model.frame(for: placed, availableWidth: 400)

        #expect(frame.contains(CGPoint(x: frame.midX, y: frame.midY)))
        #expect(!frame.contains(CGPoint(x: frame.midX, y: frame.maxY + 20)))
    }

    // MARK: - drag hit-testing

    /// `frame(for:)` floors card height at 40pt while a minute is only 64/60 pt, so two
    /// back-to-back 15-minute tasks own 16pt slots but draw 40pt rects and genuinely overlap.
    /// Cards paint in `placedTasks` order at equal zIndex, so the LAST match is the visible one —
    /// resolving a press with `.first` lifts the earlier, occluded card.
    @Test("back-to-back short tasks draw overlapping rects")
    func shortTasksOverlapOnCanvas() {
        let model = makeModel()
        let early = DailyTask(title: "A", startDate: date(hour: 9), durationMinutes: 15)
        let late = DailyTask(title: "B", startDate: date(hour: 9, minute: 15), durationMinutes: 15)
        let placedEarly = PlacedTask(task: early, column: 0, columnCount: 1)
        let placedLate = PlacedTask(task: late, column: 0, columnCount: 1)

        let a = model.frame(for: placedEarly, availableWidth: 400)
        let b = model.frame(for: placedLate, availableWidth: 400)

        #expect(a.intersects(b))
        #expect(a.height == 40)
        #expect(b.height == 40)
    }

    @Test("reverse paint order resolves a press to the visible (later) card")
    func hitTestPicksTopmostCard() {
        let model = makeModel()
        let early = DailyTask(title: "A", startDate: date(hour: 9), durationMinutes: 15)
        let late = DailyTask(title: "B", startDate: date(hour: 9, minute: 15), durationMinutes: 15)
        // `HomeModel.layout` emits ascending by startDate; preserve that ordering here.
        let placed = [
            PlacedTask(task: early, column: 0, columnCount: 1),
            PlacedTask(task: late, column: 0, columnCount: 1),
        ]

        // A point inside the overlap band, where the later card is painted on top.
        let overlapPoint = CGPoint(x: 200, y: model.frame(for: placed[1], availableWidth: 400).minY + 4)
        let hits = placed.filter { model.frame(for: $0, availableWidth: 400).contains(overlapPoint) }

        #expect(hits.count == 2)
        #expect(hits.last?.task.title == "B")
        #expect(hits.first?.task.title == "A")   // what the old `.first` lookup wrongly returned
    }

    // MARK: - layout — empty + non-overlapping

    @Test("layout returns empty for empty input")
    func layoutEmpty() {
        #expect(HomeModel.layout([]).isEmpty)
    }

    @Test("layout assigns column 0 when tasks do not overlap")
    func layoutNonOverlapping() {
        let tasks = [
            DailyTask(title: "A", startDate: date(hour: 8), durationMinutes: 60),
            DailyTask(title: "B", startDate: date(hour: 10), durationMinutes: 60),
            DailyTask(title: "C", startDate: date(hour: 14), durationMinutes: 30),
        ]
        let placed = HomeModel.layout(tasks)
        #expect(placed.count == 3)
        #expect(placed.allSatisfy { $0.column == 0 })
        #expect(placed.allSatisfy { $0.columnCount == 1 })
    }

    @Test("layout reuses column when tasks are back-to-back")
    func layoutBackToBack() {
        let tasks = [
            DailyTask(title: "A", startDate: date(hour: 9), durationMinutes: 60),
            DailyTask(title: "B", startDate: date(hour: 10), durationMinutes: 60),
        ]
        let placed = HomeModel.layout(tasks)
        #expect(placed.allSatisfy { $0.column == 0 })
        #expect(placed.allSatisfy { $0.columnCount == 1 })
    }

    // MARK: - layout — overlap

    @Test("layout splits two overlapping tasks into two columns")
    func layoutTwoOverlapping() {
        let tasks = [
            DailyTask(title: "A", startDate: date(hour: 9), durationMinutes: 90),
            DailyTask(title: "B", startDate: date(hour: 10), durationMinutes: 60),
        ]
        let placed = HomeModel.layout(tasks)
        let a = placed.first { $0.task.title == "A" }!
        let b = placed.first { $0.task.title == "B" }!
        #expect(a.column == 0)
        #expect(b.column == 1)
        #expect(placed.allSatisfy { $0.columnCount == 2 })
    }

    @Test("layout reuses earliest free column after a slot frees up")
    func layoutReusesFreeColumn() {
        let tasks = [
            DailyTask(title: "A", startDate: date(hour: 9), durationMinutes: 60),
            DailyTask(title: "B", startDate: date(hour: 9, minute: 30), durationMinutes: 60),
            DailyTask(title: "C", startDate: date(hour: 10), durationMinutes: 60),
        ]
        let placed = HomeModel.layout(tasks)
        let a = placed.first { $0.task.title == "A" }!
        let b = placed.first { $0.task.title == "B" }!
        let c = placed.first { $0.task.title == "C" }!
        #expect(a.column == 0)
        #expect(b.column == 1)
        #expect(c.column == 0)
        #expect(placed.allSatisfy { $0.columnCount == 2 })
    }
}
