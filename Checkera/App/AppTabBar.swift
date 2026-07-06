import SwiftUI

private struct AppTabBarHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct AppTabBarHeightEnvironmentKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var appTabBarHeight: CGFloat {
        get { self[AppTabBarHeightEnvironmentKey.self] }
        set { self[AppTabBarHeightEnvironmentKey.self] = newValue }
    }
}

extension View {
    func onAppTabBarHeightChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        onPreferenceChange(AppTabBarHeightPreferenceKey.self, perform: action)
    }
}

struct AppTabBar: View {
    @Binding var selection: AppTab
    let onAddTapped: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(
                tab: .home,
                title: String(localized: "Home", comment: "Tab bar label for the home screen"),
                systemImage: "calendar.day.timeline.left"
            )

            addButton

            tabButton(
                tab: .settings,
                title: String(localized: "Settings", comment: "Tab bar label for settings"),
                systemImage: "gear"
            )
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .background(alignment: .top) {
            Divider()
        }
        .background(.bar)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: AppTabBarHeightPreferenceKey.self,
                    value: proxy.size.height + proxy.safeAreaInsets.bottom
                )
            }
        )
    }

    @ViewBuilder
    private func tabButton(tab: AppTab, title: String, systemImage: String) -> some View {
        let isSelected = selection == tab
        Button {
            selection = tab
        } label: {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .regular))
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var addButton: some View {
        Button(action: onAddTapped) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .frame(width: 58, height: 58)
                .background(
                    Circle()
                        .fill(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.35), radius: 8, y: 3)
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .offset(y: -10)
        .accessibilityLabel(Text(String(localized: "Add task", comment: "Accessibility label for the add-task button on the tab bar")))
        .accessibilityHint(Text(String(localized: "Double-tap to create a new task", comment: "Accessibility hint for the add-task button")))
    }
}

#Preview("Home selected") {
    @Previewable @State var selection: AppTab = .home
    VStack {
        Spacer()
        AppTabBar(selection: $selection, onAddTapped: {})
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Settings selected") {
    @Previewable @State var selection: AppTab = .settings
    VStack {
        Spacer()
        AppTabBar(selection: $selection, onAddTapped: {})
    }
    .background(Color(.systemGroupedBackground))
}

