import SwiftUI

struct TaskRowCompact: View {
    let task: DailyTask

    var body: some View {
        HStack(spacing: 8) {
            accentBar
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text("\(task.startDate.formatted(.dateTime.hour().minute())) – \(task.endDate.formatted(.dateTime.hour().minute()))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if task.type == .golden {
                GoldenBadge()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var accentBar: some View {
        if task.type == .golden {
            Rectangle()
                .fill(LinearGradient(
                    colors: [.yellow, .orange],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 3)
                .clipShape(Capsule())
        } else {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 3)
                .clipShape(Capsule())
        }
    }
}

#Preview("Regular") {
    TaskRowCompact(task: DailyTask(title: "Team standup", startDate: .now, durationMinutes: 30, type: .regular))
        .frame(width: 320)
        .padding()
}

#Preview("Golden") {
    TaskRowCompact(task: DailyTask(title: "Deep work block", startDate: .now, durationMinutes: 90, type: .golden))
        .frame(width: 320)
        .padding()
}
