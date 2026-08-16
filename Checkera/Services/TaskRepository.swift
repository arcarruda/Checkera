import Foundation
import SwiftData
import WidgetKit

@MainActor
protocol TaskRepository {
    func tasks(for day: Date) throws -> [DailyTask]
    func insert(_ task: DailyTask) throws
    func update(_ task: DailyTask, mutate: (DailyTask) -> Void) throws
    func delete(_ task: DailyTask) throws
    func task(id: UUID) throws -> DailyTask?
}

@MainActor
struct SwiftDataTaskRepository: TaskRepository {

    let context: ModelContext

    // MARK: - Read

    func tasks(for day: Date) throws -> [DailyTask] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            return []
        }
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.startDate >= start && $0.startDate < end },
            sortBy: [SortDescriptor(\.startDate)]
        )
        return try context.fetch(descriptor)
    }

    func task(id: UUID) throws -> DailyTask? {
        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }

    // MARK: - Write

    func insert(_ task: DailyTask) throws {
        context.insert(task)
        try saveAndReloadWidgets()
    }

    func update(_ task: DailyTask, mutate: (DailyTask) -> Void) throws {
        mutate(task)
        task.updatedAt = .now
        try saveAndReloadWidgets()
    }

    func delete(_ task: DailyTask) throws {
        context.delete(task)
        try saveAndReloadWidgets()
    }

    // MARK: - Private

    private func saveAndReloadWidgets() throws {
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
