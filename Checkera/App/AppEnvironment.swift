import Foundation
import SwiftData

@MainActor
struct AppEnvironment {
    let clock: any Clock
    let repository: any TaskRepository
    let notifications: NotificationService
    let settings: SettingsModel

    static func live(modelContext: ModelContext, clock: any Clock = SystemClock()) -> AppEnvironment {
        #if DEBUG
        let notifications: NotificationService = ScreenshotMode.requestedRoute != nil
            ? NotificationService(adapter: PreviewNotificationCenter())
            : NotificationService()
        #else
        let notifications = NotificationService()
        #endif
        return AppEnvironment(
            clock: clock,
            repository: SwiftDataTaskRepository(context: modelContext),
            notifications: notifications,
            settings: SettingsModel()
        )
    }
}

#if DEBUG
extension AppEnvironment {
    static func preview(seed: [DailyTask] = DailyTask.samples, clock: any Clock = SystemClock()) -> AppEnvironment {
        let context = PersistenceController.makePreview(seed: seed)
        let suite = "preview-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        return AppEnvironment(
            clock: clock,
            repository: SwiftDataTaskRepository(context: context),
            notifications: NotificationService(adapter: PreviewNotificationCenter()),
            settings: SettingsModel(defaults: defaults)
        )
    }
}
#endif
