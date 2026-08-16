import SwiftUI

struct EmptyDayPlaceholder: View {
    let day: Day

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(emptyTitle)
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
            }
        } description: {
            Text(emptyDescription)
        }
    }

    private var emptyTitle: LocalizedStringResource {
        switch day {
        case .yesterday: "No tasks yesterday"
        case .today: "No tasks today"
        case .tomorrow: "No tasks tomorrow"
        }
    }

    private var emptyDescription: LocalizedStringResource {
        switch day {
        case .yesterday: "There weren't any tasks scheduled for yesterday."
        case .today: "Tap + to schedule one."
        case .tomorrow: "Plan ahead — add tasks for tomorrow."
        }
    }
}

#Preview("Yesterday") {
    EmptyDayPlaceholder(day: .yesterday)
}

#Preview("Today") {
    EmptyDayPlaceholder(day: .today)
}

#Preview("Tomorrow") {
    EmptyDayPlaceholder(day: .tomorrow)
}
