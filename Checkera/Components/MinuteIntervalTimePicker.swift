import SwiftUI
import UIKit

struct MinuteIntervalTimePicker: View {

    let label: Text
    @Binding var selection: Date
    @Binding var isExpanded: Bool
    var minuteInterval: Int = 15

    var body: some View {
        VStack(spacing: 0) {
            Button {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    label.foregroundStyle(.primary)
                    Spacer()
                    Text(selection, style: .time)
                        .foregroundStyle(isExpanded ? Color.accentColor : .primary)
                        .monospacedDigit()
                }
                .contentShape(Rectangle())
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(Text(selection, style: .time))
            .accessibilityHint(Text(String(
                localized: isExpanded
                    ? "Double-tap to collapse the time picker"
                    : "Double-tap to choose a time",
                comment: "Accessibility hint for inline time picker row"
            )))

            if isExpanded {
                WheelDatePickerRepresentable(
                    selection: $selection,
                    minuteInterval: minuteInterval
                )
                .frame(maxWidth: .infinity)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

private struct WheelDatePickerRepresentable: UIViewRepresentable {

    @Binding var selection: Date
    var minuteInterval: Int

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = minuteInterval
        picker.date = selection
        picker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didChange(_:)),
            for: .valueChanged
        )
        return picker
    }

    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        context.coordinator.selection = $selection
        if uiView.minuteInterval != minuteInterval {
            uiView.minuteInterval = minuteInterval
        }
        if uiView.date != selection {
            uiView.date = selection
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    @MainActor
    final class Coordinator: NSObject {

        var selection: Binding<Date>

        init(selection: Binding<Date>) {
            self.selection = selection
            super.init()
        }

        @objc func didChange(_ sender: UIDatePicker) {
            selection.wrappedValue = sender.date
        }
    }
}

#Preview {
    MinuteIntervalTimePickerPreview()
}

private struct MinuteIntervalTimePickerPreview: View {

    private enum Field { case start, end }

    @State private var start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var end = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var expanded: Field?

    var body: some View {
        Form {
            Section("Schedule") {
                MinuteIntervalTimePicker(
                    label: Text("Start"),
                    selection: $start,
                    isExpanded: Binding(
                        get: { expanded == .start },
                        set: { newValue in
                            if newValue { expanded = .start }
                            else if expanded == .start { expanded = nil }
                        }
                    )
                )
                MinuteIntervalTimePicker(
                    label: Text("End"),
                    selection: $end,
                    isExpanded: Binding(
                        get: { expanded == .end },
                        set: { newValue in
                            if newValue { expanded = .end }
                            else if expanded == .end { expanded = nil }
                        }
                    )
                )
            }
        }
    }
}
