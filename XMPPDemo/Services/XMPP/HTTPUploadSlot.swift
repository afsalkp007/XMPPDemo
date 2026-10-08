import Foundation

/// Parsed XEP-0363 upload slot returned by the XMPP server.
nonisolated struct HTTPUploadSlot: Equatable, Sendable {
    let putURL: URL
    let getURL: URL

    init(response: XMPPElement) throws {
        guard let slot = response.child(named: "slot"),
              let putNode = slot.child(named: "put"),
              let getNode = slot.child(named: "get") else {
            throw HTTPUploadSlotError.malformedResponse
        }

        let putString = putNode.attributes["url"] ?? putNode.text
        let getString = getNode.attributes["url"] ?? getNode.text

        guard let putURL = URL(string: putString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let getURL = URL(string: getString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw HTTPUploadSlotError.invalidURL
        }

        self.putURL = putURL
        self.getURL = getURL
    }
}

nonisolated enum HTTPUploadSlotError: LocalizedError, Equatable {
    case malformedResponse
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .malformedResponse:
            return "Invalid upload slot response from server"
        case .invalidURL:
            return "Invalid upload slot URLs from server"
        }
    }
}
