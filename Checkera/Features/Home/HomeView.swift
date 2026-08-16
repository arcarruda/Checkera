import SwiftUI

struct HomeView: View {

    @State private var model: HomeModel
    @State private var selectedTask: DailyTask?
    @Binding var selectedDay: Day
    let refreshTrigger: UUID
    let onEditTask: (UUID) -> Void
    let onCreateTaskAt: (Date) -> Void
    let onAddTask: () -> Void
    let onOpenSettings: () -> Void

    init(
        env: AppEnvironment,
        selectedDay: Binding<Day>,
        refreshTrigger: UUID,
        onEditTask: @escaping (UUID) -> Void,
        onCreateTaskAt: @escaping (Date) -> Void,
        onAddTask: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        _model = State(wrappedValue: HomeModel(
            clock: env.clock,
            repository: env.repository,
            notifications: env.notifications,
            settings: env.settings
        ))
        _selectedDay = selectedDay
        self.refreshTrigger = refreshTrigger
        self.onEditTask = onEditTask
        self.onCreateTaskAt = onCreateTaskAt
        self.onAddTask = onAddTask
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            DayPicker(selection: $selectedDay)
                .padding(.horizontal)
                .padding(.bottom, 8)

            TabView(selection: $selectedDay) {
                ForEach(Day.allCases) { day in
                    DayPage(
                        day: day,
                        model: model,
                        onSelectTask: { selectedTask = $0 },
                        onSelectSlot: { hour, minute in
                            let dayDate = model.date(for: day)
                            let cal = Calendar.current
                            let date = cal.date(bySettingHour: hour, minute: minute, second: 0, of: dayDate) ?? dayDate
                            onCreateTaskAt(date)
                        },
                        onDeleteTask: { task in
                            Task { await model.deleteTask(task) }
                        }
                    )
                    .tag(day)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .overlay(alignment: .bottomTrailing) {
            Group {
                if selectedDay.allowsTaskCreation {
                    FloatingAddButton(action: onAddTask)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.trailing, FloatingAddButton.margin)
            .padding(.bottom, FloatingAddButton.margin)
            .animation(.snappy(duration: 0.2), value: selectedDay.allowsTaskCreation)
        }
        .navigationTitle(Text(selectedDay.title))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text(String(localized: "Settings", comment: "Accessibility label for the toolbar button that opens the settings screen")))
            }
        }
        .task(id: refreshTrigger) {
            await model.loadAllDays()
        }
        .onChange(of: selectedDay, initial: true) { _, new in
            model.selectDay(new)
            selectedTask = nil
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailSheet(
                task: task,
                canEdit: selectedDay.allowsTaskCreation,
                onEditTask: {
                    selectedTask = nil
                    onEditTask(task.id)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

#if DEBUG
#Preview("Loaded") {
    @Previewable @State var day: Day = .today
    NavigationStack {
        HomeView(env: AppEnvironment.preview(), selectedDay: $day, refreshTrigger: UUID(), onEditTask: { _ in }, onCreateTaskAt: { _ in }, onAddTask: {}, onOpenSettings: {})
    }
}

#Preview("Empty") {
    @Previewable @State var day: Day = .today
    NavigationStack {
        HomeView(env: AppEnvironment.preview(seed: []), selectedDay: $day, refreshTrigger: UUID(), onEditTask: { _ in }, onCreateTaskAt: { _ in }, onAddTask: {}, onOpenSettings: {})
    }
}
#endif
