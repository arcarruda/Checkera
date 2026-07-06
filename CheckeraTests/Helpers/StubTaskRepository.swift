import Foundation
@testable import Checkera

@MainActor
final class StubTaskRepository: TaskRepository {

    var tasksByDate: [Date: [DailyTask]] = [:]
    var insertedTasks: [DailyTask] = []
    var updatedTasks: [DailyTask] = []
    var deletedTasks: [DailyTask] = []
    var copyCalls: [(from: Date, to: Date)] = []
    var latestPastNonEmptyDayResult: Date?
    var shouldThrow = false

    enum StubError: Error { case fail }

    func tasks(for day: Date) throws -> [DailyTask] {
        if shouldThrow { throw StubError.fail }
        let key = Calendar.current.startOfDay(for: day)
        return tasksByDate[key] ?? []
    }

    func insert(_ task: DailyTask) throws {
        if shouldThrow { throw StubError.fail }
        insertedTasks.append(task)
    }

    func update(_ task: DailyTask, mutate: (DailyTask) -> Void) throws {
        if shouldThrow { throw StubError.fail }
        mutate(task)
        updatedTasks.append(task)
    }

    func delete(_ task: DailyTask) throws {
        if shouldThrow { throw StubError.fail }
        deletedTasks.append(task)
    }

    func task(id: UUID) throws -> DailyTask? {
        if shouldThrow { throw StubError.fail }
        return tasksByDate.values.flatMap { $0 }.first { $0.id == id }
    }

    func copyTasks(from sourceDay: Date, to targetDay: Date) throws -> [DailyTask] {
        if shouldThrow { throw StubError.fail }
        copyCalls.append((sourceDay, targetDay))
        return []
    }

    func mostRecentNonEmptyDay(strictlyBefore reference: Date) throws -> Date? {
        if shouldThrow { throw StubError.fail }
        return latestPastNonEmptyDayResult
    }
}
