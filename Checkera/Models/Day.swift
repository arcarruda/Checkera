import Foundation

enum Day: Int, Hashable, CaseIterable, Sendable, Identifiable {
    case yesterday = -1
    case today = 0
    case tomorrow = 1

    var id: Int { rawValue }

    func date(relativeTo now: Date, calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: rawValue, to: startOfToday) ?? startOfToday
    }

    var title: LocalizedStringResource {
        switch self {
        case .yesterday: "Yesterday"
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        }
    }

    var allowsTaskCreation: Bool {
        switch self {
        case .yesterday: false
        case .today, .tomorrow: true
        }
    }
}
