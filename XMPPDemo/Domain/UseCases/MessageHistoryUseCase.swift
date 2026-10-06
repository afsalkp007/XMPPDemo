import Foundation

/// Loads paginated message history for a given conversation from the local store.
nonisolated struct MessageHistoryUseCase {
    private let messageStore: MessageStore

    init(messageStore: MessageStore) { self.messageStore = messageStore }

    func execute(peerJID: String, myBareJID: String, limit: Int = 100) async throws -> [Message] {
        try await messageStore.messages(for: peerJID, myBareJID: myBareJID, limit: limit)
    }

    func lastMessages(myBareJID: String) async throws -> [String: Message] {
        try await messageStore.lastMessages(myBareJID: myBareJID)
    }
}
