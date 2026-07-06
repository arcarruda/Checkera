import SwiftUI

struct HourRow: View {
    let hour: Int
    let leadingGutter: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(formattedLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: leadingGutter, alignment: .trailing)
                .padding(.trailing, 8)
                .padding(.top, -7)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                Divider()
                Spacer(minLength: 0)
            }
        }
    }

    private var formattedLabel: String {
        let cal = Calendar.current
        let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
        return date.formatted(.dateTime.hour())
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(0..<6, id: \.self) { hour in
            HourRow(hour: hour, leadingGutter: 56)
                .frame(height: 64)
        }
    }
    .padding()
}
