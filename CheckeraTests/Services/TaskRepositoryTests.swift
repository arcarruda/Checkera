import Foundation
import SwiftData
import Testing
@testable import Checkera

@MainActor
@Suite("SwiftDataTaskRepository")
struct TaskRepositoryTests {

    // MARK: - Setup

    private func makeRepository() throws -> SwiftDataTaskRepository {
        let schema = Schema([DailyTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return SwiftDataTaskRepository(context: ModelContext(container))
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

    // MARK: - insert + fetch

    @Test("inserts and fetches by day")
    func insertAndFetch() throws {
        let repo = try makeRepository()
        try repo.insert(DailyTask(title: "A", startDate: date(day: 10)))
        try repo.insert(DailyTask(title: "B", startDate: date(day: 11)))

        let onTen = try repo.tasks(for: date(day: 10))
        #expect(onTen.count == 1)
        #expect(onTen.first?.title == "A")
    }

    @Test("fetch ignores tasks on adjacent days")
    func fetchIgnoresAdjacentDays() throws {
        let repo = try makeRepository()
        try repo.insert(DailyTask(title: "Yesterday", startDate: date(day: 9, hour: 23, minute: 59)))
        try repo.insert(DailyTask(title: "Today", startDate: date(day: 10, hour: 0, minute: 0)))
        try repo.insert(DailyTask(title: "Tomorrow", startDate: date(day: 11, hour: 0, minute: 0)))

        let onTen = try repo.tasks(for: date(day: 10))
        #expect(onTen.count == 1)
        #expect(onTen.first?.title == "Today")
    }

    @Test("returns tasks sorted by startDate")
    func returnsSorted() throws {
        let repo = try makeRepository()
        try repo.insert(DailyTask(title: "Late", startDate: date(day: 10, hour: 18)))
        try repo.insert(DailyTask(title: "Early", startDate: date(day: 10, hour: 8)))
        try repo.insert(DailyTask(title: "Mid", startDate: date(day: 10, hour: 12)))

        let result = try repo.tasks(for: date(day: 10))
        #expect(result.map(\.title) == ["Early", "Mid", "Late"])
    }

    // MARK: - update

    @Test("update mutates task in place")
    func updateMutatesTask() throws {
        let repo = try makeRepository()
        let task = DailyTask(title: "Original", startDate: date(day: 10))
        try repo.insert(task)

        try repo.update(task) { $0.title = "Updated" }

        let fetched = try repo.tasks(for: date(day: 10))
        #expect(fetched.first?.title == "Updated")
    }

    @Test("update bumps updatedAt")
    func updateBumpsUpdatedAt() throws {
        let repo = try makeRepository()
        let original = Date(timeIntervalSince1970: 0)
        let task = DailyTask(title: "x", startDate: date(day: 10), createdAt: original, updatedAt: original)
        try repo.insert(task)

        try repo.update(task) { $0.title = "y" }
        #expect(task.updatedAt > original)
    }

    // MARK: - delete

    @Test("delete removes the task")
    func deleteRemovesTask() throws {
        let repo = try makeRepository()
        let task = DailyTask(title: "X", startDate: date(day: 10))
        try repo.insert(task)
        try repo.delete(task)

        #expect(try repo.tasks(for: date(day: 10)).isEmpty)
    }

    // MARK: - task(id:)

    @Test("task(id:) returns the inserted task")
    func taskByIdReturnsInserted() throws {
        let repo = try makeRepository()
        let task = DailyTask(title: "X", startDate: date(day: 10))
        try repo.insert(task)

        let fetched = try repo.task(id: task.id)
        #expect(fetched?.id == task.id)
    }

    @Test("task(id:) returns nil for unknown id")
    func taskByIdReturnsNilForUnknown() throws {
        let repo = try makeRepository()
        let fetched = try repo.task(id: UUID())
        #expect(fetched == nil)
    }
}
