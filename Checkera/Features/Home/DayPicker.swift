import SwiftUI

struct DayPicker: View {
    @Binding var selection: Day

    var body: some View {
        Picker(selection: $selection) {
            ForEach(Day.allCases) { day in
                Text(day.title).tag(day)
            }
        } label: {
            Text(String(localized: "Day", comment: "Accessibility label for the day-segment picker"))
        }
        .pickerStyle(.segmented)
    }
}

#Preview {
    @Previewable @State var day: Day = .today
    DayPicker(selection: $day)
        .padding()
}
