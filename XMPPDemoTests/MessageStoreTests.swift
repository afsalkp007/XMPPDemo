import XCTest
@testable import XMPPDemo

@MainActor
final class MessageStoreTests: XCTestCase {
    func testReturnsConversationHistoryInTimestampOrder() async throws {
        let store = makeStore()
        let first = message(id: "1", body: "First", timestamp: Date(timeIntervalSince1970: 1))
        let second = message(id: "2", body: "Second", timestamp: Date(timeIntervalSince1970: 2))

        try await store.insert(second)
        try await store.insert(first)

        let history = try await store.messages(for: "bob@localhost", myBareJID: "alice@localhost")
        XCTAssertEqual(history.map(\.id), ["1", "2"])
    }

    func testUpdatesPersistedDeliveryStatus() async throws {
        let store = makeStore()
        let sent = message(id: "message-1", body: "Hello", timestamp: .now)
        try await store.insert(sent)

        try await store.updateDeliveryStatus(id: sent.id, status: .delivered)

        let saved = try await store.messages(for: "bob@localhost", myBareJID: "alice@localhost")
        XCTAssertEqual(saved.first?.deliveryStatus, .delivered)
    }

    private func makeStore() -> MessageStore {
        MessageStore(modelContainer: PersistenceController.preview().container)
    }

    private func message(id: String, body: String, timestamp: Date) -> Message {
        Message(
            id: id,
            fromJID: "alice@localhost",
            toJID: "bob@localhost",
            body: body,
            timestamp: timestamp,
            deliveryStatus: .sent,
            isOutgoing: true
        )
    }
}
