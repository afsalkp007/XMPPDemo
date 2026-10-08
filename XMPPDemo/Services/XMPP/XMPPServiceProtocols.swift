import Foundation

/// Minimal XMPP capabilities required by the message-sending use case.
/// Keeping this contract small lets tests use a deterministic in-memory client.
nonisolated protocol XMPPMessageSending: Sendable {
    func sendMessage(to recipientJID: String, body: String) async throws -> Message
}

/// Minimal XMPP capability required before an HTTP upload can begin.
nonisolated protocol XMPPUploadSlotRequesting: Sendable {
    func requestUploadSlot(filename: String, size: Int, mimeType: String) async throws -> (putURL: URL, getURL: URL)
}
