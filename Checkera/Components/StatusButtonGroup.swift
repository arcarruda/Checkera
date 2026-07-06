import SwiftUI

struct StatusButtonGroup: View {
    let status: TaskStatus
    let onSelect: (TaskStatus) -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusButton(.accomplished, icon: "checkmark.circle.fill", color: .green)
            statusButton(.notAccomplished, icon: "xmark.circle.fill", color: .red)
            statusButton(.lateAccomplished, icon: "clock.badge.checkmark.fill", color: .orange)
        }
    }

    @ViewBuilder
    private func statusButton(_ option: TaskStatus, icon: String, color: Color) -> some View {
        let isSelected = status == option
        Button {
            onSelect(option)
        } label: {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isSelected ? Color.white : color)
                .frame(minWidth: 44, minHeight: 44)
                .background {
                    if isSelected {
                        Circle().fill(color)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.accessibilityLabel))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension TaskStatus {
    var accessibilityLabel: LocalizedStringResource {
        switch self {
        case .pending: "Mark pending"
        case .accomplished: "Mark accomplished"
        case .notAccomplished: "Mark not accomplished"
        case .lateAccomplished: "Mark late accomplished"
        }
    }
}

#Preview {
    StatusButtonGroup(status: .accomplished, onSelect: { _ in })
        .padding()
}
