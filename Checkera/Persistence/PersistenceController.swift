import Foundation
import SwiftData
import os

enum PersistenceController {

    static let appGroupIdentifier = "group.app.topera.checkera"
    static let storeFileName = "Checkera.sqlite"

    /// The shared store, or `nil` if it could not be opened.
    ///
    /// Prefer this in extensions. The widget is often the first process to touch the store
    /// after an app update — i.e. the first to run a schema migration — and a crash there is
    /// an unrecoverable blank widget, so it degrades to an empty timeline instead.
    static let sharedIfAvailable: ModelContainer? = {
        let schema = Schema([DailyTask.self])
        let config: ModelConfiguration
        if let url = sharedStoreURL() {
            config = ModelConfiguration(schema: schema, url: url)
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            logger.error("Failed to create ModelContainer: \(error, privacy: .public)")
            return nil
        }
    }()

    /// The shared store for the app itself, where there is no sensible way to continue without it.
    static var shared: ModelContainer {
        guard let container = sharedIfAvailable else {
            fatalError("Failed to create ModelContainer")
        }
        return container
    }

    private static let logger = Logger(subsystem: "app.checkera", category: "Persistence")

    static func sharedStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(storeFileName)
    }

    @MainActor
    static func makePreview(seed: [DailyTask] = []) -> ModelContext {
        let schema = Schema([DailyTask.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            let context = ModelContext(container)
            for task in seed {
                context.insert(task)
            }
            try? context.save()
            return context
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
}
