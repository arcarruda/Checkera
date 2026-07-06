import Foundation

struct TaskSnapshot: Hashable, Sendable, Identifiable {
    let id: UUID
    let title: String
    let startDate: Date
    let durationMinutes: Int

    var endDate: Date {
        startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    init(id: UUID, title: String, startDate: Date, durationMinutes: Int) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.durationMinutes = durationMinutes
    }

    init(_ task: DailyTask) {
        self.init(
            id: task.id,
            title: task.title,
            startDate: task.startDate,
            durationMinutes: task.durationMinutes
        )
    }
}

extension Array where Element == TaskSnapshot {
    func active(at date: Date) -> [TaskSnapshot] {
        filter { $0.startDate <= date && date < $0.endDate }
    }

    func next(after date: Date) -> TaskSnapshot? {
        first { $0.startDate > date }
    }

    func lastEnded(before date: Date) -> TaskSnapshot? {
        filter { $0.endDate <= date }
            .max(by: { $0.endDate < $1.endDate })
    }

    func justStarted(within minutes: Int, of date: Date) -> TaskSnapshot? {
        active(at: date).first { date.timeIntervalSince($0.startDate) < TimeInterval(minutes * 60) }
    }
}
