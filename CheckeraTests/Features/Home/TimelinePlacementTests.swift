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
