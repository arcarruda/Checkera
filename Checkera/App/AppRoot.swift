import SwiftUI
import os

private enum EditorPresentation: Identifiable {
    case add(prefilledStart: Date)
    case edit(UUID)

    var id: String {
        switch self {
        case .add(let date): "add-\(Int(date.timeIntervalSince1970))"
        case .edit(let id): "edit-\(id.uuidString)"
        }
    }
}

struct AppRoot: View {

    @State private var editorPresentation: EditorPresentation?
    @State private var refreshTrigger = UUID()
    @State private var selectedDay: Day = .today
    @State private var isShowingSettings = false
    @Environment(\.scenePhase) private var scenePhase
    let env: AppEnvironment

    private let logger = Logger(subsystem: "app.checkera", category: "AppRoot")

    var body: some View {
        NavigationStack {
            HomeView(
                env: env,
                selectedDay: $selectedDay,
                refreshTrigger: refreshTrigger,
                onEditTask: { id in
                    editorPresentation = .edit(id)
                },
                onCreateTaskAt: { date in
                    editorPresentation = .add(prefilledStart: date)
                },
                onAddTask: {
                    editorPresentation = .add(prefilledStart: prefilledStart())
                },
                onOpenSettings: {
                    isShowingSettings = true
                }
            )
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView(model: env.settings, notifications: env.notifications)
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $editorPresentation, onDismiss: {
            refreshTrigger = UUID()
        }) { presentation in
            NavigationStack {
                switch presentation {
                case .add(let date):
                    TaskEditorView(mode: .add(prefilledStart: date), env: env, onSaved: { day in
                        selectedDay = day
                    })
                case .edit(let id):
                    TaskEditorView(mode: .edit(taskID: id), env: env, onSaved: { day in
                        selectedDay = day
                    })
                }
            }
        }
        .preferredColorScheme(env.settings.themePreference.colorScheme)
        .onOpenURL { url in
            handleURL(url)
        }
        .task {
            await refreshTodayNotifications()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await refreshTodayNotifications() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { await refreshTodayNotifications() }
        }
        .onAppear {
            #if DEBUG
            applyScreenshotRouteIfNeeded()
            #endif
        }
    }

    #if DEBUG
    private func applyScreenshotRouteIfNeeded() {
        guard let route = ScreenshotMode.requestedRoute else { return }
        switch route {
        case .home:
            selectedDay = .today
        case .settings:
            isShowingSettings = true
        case .editor:
            selectedDay = .today
            editorPresentation = .edit(ScreenshotMode.editorShowcaseID)
        }
    }
    #endif

    private func refreshTodayNotifications() async {
        let granted = await env.notifications.requestAuthorizationIfNeeded()
        guard granted else { return }
        let now = env.clock.now
        do {
            let tasks = try env.repository.tasks(for: now)
            for task in tasks {
                await env.notifications.schedule(
                    task,
                    tone: env.settings.tone(for: task.color),
                    now: now
                )
            }
        } catch {
            logger.error("refreshTodayNotifications failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "checkera", url.host == "today" else { return }
        isShowingSettings = false
        selectedDay = .today
    }

    private func prefilledStart() -> Date {
        let cal = Calendar.current
        let now = env.clock.now
        let targetDay: Day = selectedDay == .yesterday ? .today : selectedDay
        let dayDate = targetDay.date(relativeTo: now, calendar: cal)
        let nowHour = cal.component(.hour, from: now)
        let nextHour = nowHour < 23 ? nowHour + 1 : 23
        return cal.date(bySettingHour: nextHour, minute: 0, second: 0, of: dayDate) ?? dayDate
    }
}

#if DEBUG
#Preview {
    AppRoot(env: AppEnvironment.preview())
}
#endif
