import Foundation

/// Encapsulates connect / reconnect logic, shielding ViewModels from raw XMPPManager API.
nonisolated struct ConnectUseCase {
    private let xmpp: XMPPManager

    init(xmpp: XMPPManager) { self.xmpp = xmpp }

    func execute(jid: String, password: String, host: String? = nil, port: Int = 5222) async throws {
        guard !jid.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else {
            throw XMPPError.invalidJID
        }
        try await xmpp.connect(jid: jid, password: password, host: host, port: port)
    }

    func disconnect() async {
        await xmpp.disconnect()
    }
}
