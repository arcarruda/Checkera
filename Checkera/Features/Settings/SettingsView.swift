import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {

    private enum ExpandedSleepField { case wake, bed }

    private enum TestAlert: Identifiable {
        case scheduled, denied
        var id: Self { self }
    }

    @State private var model: SettingsModel
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var expandedSleepField: ExpandedSleepField?
    @State private var testAlert: TestAlert?
    @Environment(\.dismiss) private var dismiss
    private let notifications: NotificationService

    init(model: SettingsModel, notifications: NotificationService) {
        _model = State(wrappedValue: model)
        self.notifications = notifications
    }

    var body: some View {
        @Bindable var model = model
        return Form {
            Section {
                Picker(selection: $model.themePreference) {
                    ForEach(ThemePreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                } label: {
                    Label {
                        Text(String(localized: "Theme", comment: "Picker label for app theme preference"))
                    } icon: {
                        Image(systemName: "circle.lefthalf.filled")
                    }
                }
            } header: {
                Text(String(localized: "Appearance", comment: "Settings section header for appearance preferences"))
            }

            Section {
                MinuteIntervalTimePicker(
                    label: Text(String(localized: "Wake up", comment: "Settings row label for wake-up time")),
                    selection: dateBinding(for: \.wakeUpMinute),
                    isExpanded: expansionBinding(for: .wake)
                )
                MinuteIntervalTimePicker(
                    label: Text(String(localized: "Bedtime", comment: "Settings row label for bedtime")),
                    selection: dateBinding(for: \.bedTimeMinute),
                    isExpanded: expansionBinding(for: .bed)
                )
            } header: {
                Text(String(localized: "Sleep schedule", comment: "Settings section header for sleep schedule preferences"))
            } footer: {
                Text(String(localized: "This period is marked with a green dashed line on the timeline. You can still add tasks here.", comment: "Footer explaining the green dashed line shown alongside the timeline for the sleep window"))
            }

            Section {
                ForEach(TaskColor.allCases) { color in
                    Picker(selection: model.toneBinding(for: color)) {
                        ForEach(NotificationTone.allCases.filter { ($0.category == .golden) == color.isAlarm }, id: \.self) { tone in
                            Text(tone.title).tag(tone)
                        }
                    } label: {
                        Label {
                            Text(color.title)
                        } icon: {
                            TaskColorDot(color: color)
                        }
                    }
                }
            } header: {
                Text(String(localized: "Task tones", comment: "Settings section header for the per-colour tone pickers"))
            } footer: {
                Text(String(localized: "Each colour plays its own tone when a task starts. Gold tasks alarm: they arrive as time sensitive and can be snoozed.", comment: "Footer explaining per-colour tones and what makes gold different"))
            }

            Section {
                authorizationRow
            } header: {
                Text(String(localized: "Notifications", comment: "Settings section header for notification permissions"))
            } footer: {
                Text(String(localized: "Custom audio for each tone ships in a future update; all tones currently use the system default sound.", comment: "Footer explaining v1 tone limitation"))
            }

            Section {
                Button {
                    Task {
                        let scheduled = await notifications.scheduleTestNotification()
                        authorizationStatus = await notifications.authorizationStatus()
                        testAlert = scheduled ? .scheduled : .denied
                    }
                } label: {
                    Label {
                        Text(String(localized: "Send test notification in 1 minute", comment: "Settings button that schedules a test local notification 60 seconds in the future"))
                    } icon: {
                        Image(systemName: "paperplane")
                    }
                }
            } header: {
                Text(String(localized: "Diagnostics", comment: "Settings section header for diagnostic and testing tools"))
            } footer: {
                Text(String(localized: "Schedules a notification 1 minute from now. Background the app to verify it presents.", comment: "Footer explaining how to use the test notification button"))
            }

            Section {
                brandFooter
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .navigationTitle(Text(String(localized: "Settings", comment: "Settings screen title")))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Done", comment: "Button that dismisses the settings sheet")) {
                    dismiss()
                }
            }
        }
        .task {
            authorizationStatus = await notifications.authorizationStatus()
        }
        .alert(
            String(localized: "Test notification scheduled", comment: "Alert title shown after tapping the test notification button"),
            isPresented: testAlertBinding(for: .scheduled)
        ) {
            Button(String(localized: "OK", comment: "Generic OK button"), role: .cancel) { }
        } message: {
            Text(String(localized: "Background the app within 1 minute to see the notification.", comment: "Alert message instructing the user to background the app"))
        }
        .alert(
            String(localized: "Notifications disabled", comment: "Alert title when test notification cannot be sent because permission was denied"),
            isPresented: testAlertBinding(for: .denied)
        ) {
            Button(String(localized: "OK", comment: "Generic OK button"), role: .cancel) { }
        } message: {
            Text(String(localized: "Enable notifications for Checkera in Settings to test.", comment: "Alert message instructing user to enable notifications in iOS Settings"))
        }
    }

    private func testAlertBinding(for alert: TestAlert) -> Binding<Bool> {
        Binding(
            get: { testAlert == alert },
            set: { newValue in
                if !newValue && testAlert == alert { testAlert = nil }
            }
        )
    }

    private var brandFooter: some View {
        VStack(spacing: 6) {
            Image("BrandLogo")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 18)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text(String(localized: "Checkera", comment: "Accessibility label for the Checkera wordmark in settings footer")))
            Text(versionString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    private func dateBinding(for keyPath: ReferenceWritableKeyPath<SettingsModel, Int>) -> Binding<Date> {
        Binding(
            get: { SettingsModel.date(fromMinutesFromMidnight: model[keyPath: keyPath]) },
            set: { model[keyPath: keyPath] = SettingsModel.minutesFromMidnight(of: $0) }
        )
    }

    private func expansionBinding(for field: ExpandedSleepField) -> Binding<Bool> {
        Binding(
            get: { expandedSleepField == field },
            set: { newValue in
                if newValue { expandedSleepField = field }
                else if expandedSleepField == field { expandedSleepField = nil }
            }
        )
    }

    @ViewBuilder
    private var authorizationRow: some View {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Label {
                Text(String(localized: "Notifications enabled", comment: "Status row when notifications are allowed"))
            } icon: {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(String(localized: "Notifications disabled", comment: "Status row when notifications are denied"))
                } icon: {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                }
                Text(String(localized: "Enable notifications for Checkera in the system Settings to be reminded when tasks start.", comment: "Instruction to enable notifications"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "Open Settings", comment: "Button that opens iOS Settings app"))
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            }
        case .notDetermined:
            Label {
                Text(String(localized: "Permission not requested yet", comment: "Status row when notification authorization has not been requested"))
            } icon: {
                Image(systemName: "questionmark.circle.fill").foregroundStyle(.secondary)
            }
        @unknown default:
            EmptyView()
        }
    }
}

extension NotificationTone {
    var title: LocalizedStringResource {
        switch self {
        case .regularDefault: "Default"
        case .regularChime: "Chime"
        case .regularSubtle: "Subtle"
        case .goldenBell: "Bell"
        case .goldenFanfare: "Fanfare"
        case .goldenChime: "Golden chime"
        }
    }
}

#if DEBUG
#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                SettingsView(
                    model: SettingsModel(defaults: UserDefaults(suiteName: "preview")!),
                    notifications: NotificationService(adapter: PreviewNotificationCenter())
                )
            }
            .presentationDragIndicator(.visible)
        }
}
#endif
