import SwiftUI

struct TimelineBar: View {

    let tasks: [TaskSnapshot]
    let referenceDate: Date
    var drawDots: Bool = true

    private static let trackColor = Color(red: 0.137, green: 0.239, blue: 0.302) // #233d4d
    private static let fillColor = Color("AccentColor")
    private static let dotSize: CGFloat = 10
    private static let trackHeight: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Self.trackColor.opacity(0.7))
                    .frame(height: Self.trackHeight)
                    .frame(maxHeight: .infinity, alignment: .center)

                Capsule()
                    .fill(Self.fillColor)
                    .frame(width: geo.size.width * progress(referenceDate), height: Self.trackHeight)
                    .frame(maxHeight: .infinity, alignment: .center)

                if drawDots {
                    ForEach(tasks) { task in
                        Circle()
                            .fill(dotColor(for: task))
                            .frame(width: Self.dotSize, height: Self.dotSize)
                            .offset(x: dotOffset(for: task, in: geo.size.width))
                            .frame(maxHeight: .infinity, alignment: .center)
                    }
                }
            }
        }
    }

    private func progress(_ date: Date) -> CGFloat {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return min(1, max(0, CGFloat(minutes) / 1440))
    }

    private func dotColor(for task: TaskSnapshot) -> Color {
        task.startDate <= referenceDate ? Self.fillColor : Self.trackColor
    }

    private func dotOffset(for task: TaskSnapshot, in width: CGFloat) -> CGFloat {
        let center = width * progress(task.startDate)
        return min(width - Self.dotSize, max(0, center - Self.dotSize / 2))
    }
}
