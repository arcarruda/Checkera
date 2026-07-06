import Foundation
import SwiftData
import WidgetKit
import os

@MainActor
protocol TaskRepository {
    func tasks(for day: Date) throws -> [DailyTask]
    func insert(_ task: DailyTask) throws
    func update(_ task: DailyTask, mutate: (DailyTask) -> Void) throws
    func delete(_ task: DailyTask) throws
    func task(id: UUID) throws -> DailyTask?
    func copyTasks(from sourceDay: Date, to targetDay: Date) throws -> [DailyTask]
    func mostRecentNonEmptyDay(strictlyBefore reference: Date) throws -> Date?
}

@MainActor
struct SwiftDataTaskRepository: TaskRepository {

    let context: ModelContext
    private let logger = Logger(subsystem: "app.checkera", category: "TaskRepository")

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

    func mostRecentNonEmptyDay(strictlyBefore reference: Date) throws -> Date? {
        let cal = Calendar.current
        let cutoff = cal.startOfDay(for: reference)
        var descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.startDate < cutoff },
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let latest = try context.fetch(descriptor).first else { return nil }
        return cal.startOfDay(for: latest.startDate)
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

    // MARK: - Copy

    func copyTasks(from sourceDay: Date, to targetDay: Date) throws -> [DailyTask] {
        let cal = Calendar.current
        let originals = try tasks(for: sourceDay)
        let targetStartOfDay = cal.startOfDay(for: targetDay)
        var inserted: [DailyTask] = []
        inserted.reserveCapacity(originals.count)

        for original in originals {
            let comps = cal.dateComponents([.hour, .minute], from: original.startDate)
            let newStart = cal.date(
                bySettingHour: comps.hour ?? 0,
                minute: comps.minute ?? 0,
                second: 0,
                of: targetStartOfDay
            ) ?? targetStartOfDay

            let copy = DailyTask(
                title: original.title,
                details: original.details,
                startDate: newStart,
                durationMinutes: original.durationMinutes,
                endTimeWasManuallyEdited: original.endTimeWasManuallyEdited,
                type: original.type,
                status: .pending
            )
            context.insert(copy)
            inserted.append(copy)
        }
        try saveAndReloadWidgets()
        logger.info("copied \(inserted.count, privacy: .public) tasks across days")
        return inserted
    }

    // MARK: - Private

    private func saveAndReloadWidgets() throws {
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
