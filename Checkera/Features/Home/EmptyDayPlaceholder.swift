import SwiftUI

struct EmptyDayPlaceholder: View {
    let day: Day
    let bringInPlan: DayCopyService.BringInPlan?
    let onBringIn: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(emptyTitle)
            } icon: {
                Image(systemName: "calendar.badge.exclamationmark")
            }
        } description: {
            Text(emptyDescription)
        } actions: {
            if bringInPlan != nil {
                BringInTasksButton(onTap: onBringIn)
                    .padding(.top, 8)
            }
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
        case .today: "Tap the Add tab to schedule one."
        case .tomorrow: "Plan ahead — add tasks for tomorrow."
        }
    }
}

#Preview("Today, no plan") {
    EmptyDayPlaceholder(day: .today, bringInPlan: nil, onBringIn: {})
}

#Preview("Today, with plan") {
    EmptyDayPlaceholder(
        day: .today,
        bringInPlan: DayCopyService.BringInPlan(source: .now, target: .today),
        onBringIn: {}
    )
}

#Preview("Tomorrow, with plan") {
    EmptyDayPlaceholder(
        day: .tomorrow,
        bringInPlan: DayCopyService.BringInPlan(source: .now, target: .tomorrow),
        onBringIn: {}
    )
}
