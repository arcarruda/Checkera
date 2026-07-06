import SwiftUI

struct TaskEditorView: View {

    private enum ExpandedTimeField { case start, end }

    @State private var model: TaskEditorModel
    @State private var expandedTimeField: ExpandedTimeField?
    @Environment(\.dismiss) private var dismiss

    private let onSaved: (Day) -> Void

    init(mode: TaskEditorModel.Mode, env: AppEnvironment, onSaved: @escaping (Day) -> Void = { _ in }) {
        _model = State(wrappedValue: TaskEditorModel(
            mode: mode,
            repository: env.repository,
            clock: env.clock,
            notifications: env.notifications,
            settings: env.settings
        ))
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var model = model
        return Group {
            if model.loadFailed {
                loadFailedView
            } else {
                form(model: model)
            }
        }
        .navigationTitle(Text(model.isEditing
            ? String(localized: "Edit Task", comment: "Title for editing an existing task")
            : String(localized: "New Task", comment: "Title for adding a new task")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", comment: "Cancel button in task editor")) {
                    dismiss()
                }
            }
            if !model.loadFailed {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", comment: "Save button in task editor")) {
                        Task {
                            let saved = await model.save()
                            if saved {
                                onSaved(model.taskDay)
                                dismiss()
                            }
                        }
                    }
                    .disabled(!model.canSave || model.isSaving)
                    .tint(.green)
                }
            }
        }
    }

    private var loadFailedView: some View {
        ContentUnavailableView {
            Label {
                Text(String(localized: "Task not found", comment: "Title shown when an edited task can't be loaded"))
            } icon: {
                Image(systemName: "questionmark.folder")
            }
        } description: {
            Text(String(localized: "This task may have been deleted. Close this screen to return.", comment: "Description shown when an edited task is missing"))
        }
    }

    @ViewBuilder
    private func form(model: TaskEditorModel) -> some View {
        @Bindable var model = model
        ScrollViewReader { proxy in
            Form {
                Section {
                    HStack(spacing: 8) {
                        TextField(
                            String(localized: "What needs doing?", comment: "Task title placeholder"),
                            text: $model.title
                        )
                        .textInputAutocapitalization(.sentences)
                        .accessibilityLabel(Text(String(localized: "Task title", comment: "Accessibility label for the title field")))

                        Button {
                            model.type = (model.type == .golden) ? .regular : .golden
                        } label: {
                            Group {
                                if model.type == .golden {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ))
                                } else {
                                    Image(systemName: "star")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.title3)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(String(localized: "Mark as golden", comment: "Accessibility label for the golden task toggle button")))
                        .accessibilityValue(Text(model.type == .golden
                            ? String(localized: "Golden", comment: "Accessibility value when task is marked golden")
                            : String(localized: "Regular", comment: "Accessibility value when task is not marked golden")))
                        .accessibilityAddTraits(model.type == .golden ? .isSelected : [])
                    }
                } header: {
                    Text(String(localized: "Title", comment: "Title section header"))
                }

                Section {
                    TextField(
                        String(localized: "Why does this matter?", comment: "Task details placeholder"),
                        text: $model.details,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel(Text(String(localized: "Task details", comment: "Accessibility label for the details field")))
                } header: {
                    Text(String(localized: "Details", comment: "Details section header"))
                }

                Section {
                    Picker(selection: $model.taskDay) {
                        Text(String(localized: "Today", comment: "For: today option")).tag(Day.today)
                        Text(String(localized: "Tomorrow", comment: "For: tomorrow option")).tag(Day.tomorrow)
                    } label: {
                        Text(String(localized: "For", comment: "For picker label"))
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: model.taskDay) { _, newDay in
                        model.applyTaskDay(newDay)
                    }
                    .accessibilityLabel(Text(String(localized: "For", comment: "Accessibility label for day picker")))
                } header: {
                    Text(String(localized: "For", comment: "For section header"))
                }

                Section {
                    MinuteIntervalTimePicker(
                        label: Text(String(localized: "Start", comment: "Start time picker label")),
                        selection: $model.startDate,
                        isExpanded: Binding(
                            get: { expandedTimeField == .start },
                            set: { newValue in
                                if newValue { expandedTimeField = .start }
                                else if expandedTimeField == .start { expandedTimeField = nil }
                            }
                        )
                    )
                    .id(ExpandedTimeField.start)
                    Picker(selection: $model.durationMinutes) {
                        ForEach(TaskEditorModel.presetDurations, id: \.self) { minutes in
                            Text(formattedDuration(minutes)).tag(minutes)
                        }
                    } label: {
                        Text(String(localized: "Duration", comment: "Duration picker label"))
                    }
                    MinuteIntervalTimePicker(
                        label: Text(String(localized: "End", comment: "Label for the end time of an event.")),
                        selection: $model.endDate,
                        isExpanded: Binding(
                            get: { expandedTimeField == .end },
                            set: { newValue in
                                if newValue { expandedTimeField = .end }
                                else if expandedTimeField == .end { expandedTimeField = nil }
                            }
                        )
                    )
                    .id(ExpandedTimeField.end)
                } header: {
                    Text(String(localized: "Schedule", comment: "Schedule section header"))
                }

                if model.isEditing {
                    Section {
                        SlideToDeleteButton {
                            let deleted = await model.delete()
                            if deleted { dismiss() }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }

                if let error = model.saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .accessibilityLabel(Text(String(localized: "Save error: \(error)", comment: "Accessibility label for save error message")))
                    }
                }
            }
            .onChange(of: expandedTimeField) { _, newValue in
                guard let field = newValue else { return }
                withAnimation {
                    proxy.scrollTo(field, anchor: .center)
                }
            }
        }
    }

    private func formattedDuration(_ minutes: Int) -> String {
        let duration = Duration.seconds(minutes * 60)
        return duration.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

#if DEBUG
#Preview("Add") {
    NavigationStack {
        TaskEditorView(mode: .add(prefilledStart: nil), env: AppEnvironment.preview())
    }
}

#Preview("Edit") {
    NavigationStack {
        TaskEditorView(
            mode: .edit(taskID: DailyTask.samples.first!.id),
            env: AppEnvironment.preview()
        )
    }
}
#endif
