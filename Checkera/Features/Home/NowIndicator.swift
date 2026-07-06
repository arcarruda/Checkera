import SwiftUI

struct NowIndicator: View {
    let leadingGutter: CGFloat
    let yOffsetForDate: (Date) -> CGFloat

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let y = yOffsetForDate(now)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.green)
                    .frame(height: 2)
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .offset(x: leadingGutter - 5)
                    .shadow(color: .green.opacity(0.4), radius: 4)
            }
            .offset(y: y - 1)
            .accessibilityElement()
            .accessibilityLabel(Text(String(localized: "Current time", comment: "Now indicator accessibility label")))
            .accessibilityValue(Text(now.formatted(.dateTime.hour().minute())))
        }
    }
}

#Preview {
    ZStack(alignment: .topLeading) {
        Color(.systemGroupedBackground)
        NowIndicator(leadingGutter: 56, yOffsetForDate: { _ in 200 })
    }
    .frame(height: 480)
}
