import Foundation

/// Loads the roster from both local cache and network, merging results.
nonisolated struct FetchRosterUseCase {
    private let rosterStore: RosterStore

    init(rosterStore: RosterStore) { self.rosterStore = rosterStore }

    func execute() async throws -> [Contact] {
        try await rosterStore.allContacts()
    }
}
