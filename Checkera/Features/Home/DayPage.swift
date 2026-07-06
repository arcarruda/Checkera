import SwiftUI

struct DayPage: View {
    let day: Day
    let model: HomeModel
    let onSelectTask: (DailyTask) -> Void
    let onSelectSlot: (Int, Int) -> Void
    let onDeleteTask: (DailyTask) -> Void

    var body: some View {
        let tasks = model.tasks(for: day)
        Group {
            if tasks.isEmpty {
                let plan = model.bringInPlan(for: day)
                EmptyDayPlaceholder(
                    day: day,
                    bringInPlan: plan,
                    onBringIn: {
                        if let plan {
                            Task { await model.acceptBringIn(plan) }
                        }
                    }
                )
            } else {
                DayTimelineView(
                    day: day,
                    placedTasks: HomeModel.layout(tasks),
                    model: model,
                    onSelectTask: onSelectTask,
                    onSelectSlot: onSelectSlot,
                    onDeleteTask: onDeleteTask
                )
            }
        }
    }
}
