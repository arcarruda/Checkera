import SwiftUI
import SwiftData
import UserNotifications

@main
struct CheckeraApp: App {

    private let notificationDelegate = NotificationDelegate()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationCategoryRegistrar.registerAll()
        #if DEBUG
        if ScreenshotMode.shouldSeed {
            MainActor.assumeIsolated { ScreenshotSeed.populateIfNeeded() }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(PersistenceController.shared)
    }
}

private struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        AppRoot(env: AppEnvironment.live(modelContext: modelContext))
    }
}
