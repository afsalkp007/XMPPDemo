import Foundation

/// Sends an outgoing message and persists it immediately (optimistic local insert).
nonisolated struct SendMessageUseCase {
    private let xmpp:         XMPPManager
    private let messageStore: MessageStore

    init(xmpp: XMPPManager, messageStore: MessageStore) {
        self.xmpp         = xmpp
        self.messageStore = messageStore
    }

    /// Returns the domain `Message` once sent. Persists with `.sent` status.
    @discardableResult
    func execute(to recipientJID: String, body: String) async throws -> Message {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SendError.emptyBody }

        let message = try await xmpp.sendMessage(to: recipientJID, body: trimmed)
        try await messageStore.insert(message)
        NotificationCenter.default.post(name: .xmppOutboundMessage, object: nil, userInfo: ["message": message])
        return message
    }

    enum SendError: LocalizedError {
        case emptyBody
        var errorDescription: String? { "Message body cannot be empty" }
    }
}
