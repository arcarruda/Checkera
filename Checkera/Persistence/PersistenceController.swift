import Foundation
import SwiftData

enum PersistenceController {

    static let appGroupIdentifier = "group.app.topera.checkera"
    static let storeFileName = "Checkera.sqlite"

    static let shared: ModelContainer = {
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
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

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
