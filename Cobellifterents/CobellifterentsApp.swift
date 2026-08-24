import SwiftData
import SwiftUI

@main
struct CobellifterentsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            WorkoutSetRecord.self,
            ImportedRawRecord.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create SwiftData ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
