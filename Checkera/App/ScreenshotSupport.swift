#if DEBUG
import Foundation
import SwiftData

enum ScreenshotMode {
    static var shouldSeed: Bool {
        CommandLine.arguments.contains("--screenshot-seed")
    }

    static var requestedRoute: Route? {
        for arg in CommandLine.arguments where arg.hasPrefix("--screenshot-route=") {
            let raw = arg.dropFirst("--screenshot-route=".count)
            return Route(rawValue: String(raw))
        }
        return nil
    }

    enum Route: String {
        case home
        case editor
        case settings
    }

    static let editorShowcaseID = UUID(uuidString: "C4ECCE2A-4ED1-4ED1-4ED1-4ED14ED14ED1")!
}

enum ScreenshotSeed {

    @MainActor
    static func populateIfNeeded() {
        let container = PersistenceController.shared
        let context = ModelContext(container)

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else { return }

        let descriptor = FetchDescriptor<DailyTask>(
            predicate: #Predicate { $0.startDate >= today && $0.startDate < tomorrow }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        for task in existing {
            context.delete(task)
        }

        for task in showcaseTasks(today: today, calendar: cal) {
            context.insert(task)
        }
        try? context.save()
    }

    private static func showcaseTasks(today: Date, calendar cal: Calendar) -> [DailyTask] {
        func at(_ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }
        return [
            DailyTask(
                title: "Morning run",
                startDate: at(6, 30),
                durationMinutes: 30,
                color: .teal,
                status: .accomplished
            ),
            DailyTask(
                title: "Cold shower & coffee",
                startDate: at(7, 15),
                durationMinutes: 30,
                color: .blue,
                status: .accomplished
            ),
            DailyTask(
                title: "Team standup",
                details: "Daily sync with the iOS guild.",
                startDate: at(9, 30),
                durationMinutes: 30,
                color: .purple,
                status: .accomplished
            ),
            DailyTask(
                title: "Deep work: Q2 planning",
                details: "Map out the next quarter's roadmap.",
                startDate: at(10, 15),
                durationMinutes: 90,
                color: .gold,
                status: .accomplished
            ),
            DailyTask(
                title: "Lunch with Marina",
                startDate: at(13, 0),
                durationMinutes: 60,
                color: .pink,
                status: .pending
            ),
            DailyTask(
                id: ScreenshotMode.editorShowcaseID,
                title: "Customer interview",
                details: "Renan from Linha 14. Prep follow-up questions.",
                startDate: at(14, 30),
                durationMinutes: 45,
                color: .gold,
                status: .pending
            ),
            DailyTask(
                title: "Evening walk",
                startDate: at(18, 30),
                durationMinutes: 30,
                color: .red,
                status: .pending
            ),
            DailyTask(
                title: "Reading",
                details: "Continue Project Hail Mary.",
                startDate: at(21, 0),
                durationMinutes: 30,
                color: .gold,
                status: .pending
            ),
        ]
    }
}
#endif
