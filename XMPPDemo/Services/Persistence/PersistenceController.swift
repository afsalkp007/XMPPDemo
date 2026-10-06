import Foundation
import SwiftData

/// Bootstraps and vends the shared SwiftData `ModelContainer`.
@MainActor
final class PersistenceController {

    static let shared = PersistenceController()

    let container: ModelContainer

    private init() {
        let schema = Schema([MessageRecord.self, ContactRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData container init failed: \(error)")
        }
    }

    /// In-memory container for XCTest — no disk I/O, isolated per test.
    static func preview() -> PersistenceController {
        let ctrl = PersistenceController(inMemory: true)
        return ctrl
    }

    private init(inMemory: Bool) {
        let schema = Schema([MessageRecord.self, ContactRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Preview SwiftData container init failed: \(error)")
        }
    }
}
