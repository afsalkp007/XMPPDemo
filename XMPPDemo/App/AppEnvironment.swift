import Foundation
import Observation
import Security
import SwiftData

// MARK: - AppEnvironment
//
// Root dependency injection container.
// Uses @Observable (iOS 17+) instead of ObservableObject to correctly support
// @MainActor isolation under SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.

@MainActor
@Observable
final class AppEnvironment {

    // MARK: - Singleton

    static let shared = AppEnvironment()

    // MARK: - Core Services

    let xmpp = XMPPManager()
    let persistence: PersistenceController
    let messageStore: MessageStore
    let rosterStore:  RosterStore

    // MARK: - Use Cases

    let connectUseCase:        ConnectUseCase
    let sendMessageUseCase:    SendMessageUseCase
    let fetchRosterUseCase:    FetchRosterUseCase
    let messageHistoryUseCase: MessageHistoryUseCase

    // MARK: - Session State (observed by views automatically via @Observable)

    var connectionState: ConnectionState = .disconnected
    var myBareJID: String = ""
    var isLoggedIn: Bool = false

    // MARK: - Init

    private init() {
        persistence  = PersistenceController.shared
        messageStore = MessageStore(modelContainer: persistence.container)
        rosterStore  = RosterStore(modelContainer: persistence.container)

        let xmpp = self.xmpp
        connectUseCase        = ConnectUseCase(xmpp: xmpp)
        sendMessageUseCase    = SendMessageUseCase(xmpp: xmpp, messageStore: messageStore)
        fetchRosterUseCase    = FetchRosterUseCase(rosterStore: rosterStore)
        messageHistoryUseCase = MessageHistoryUseCase(messageStore: messageStore)

        // Observe XMPP connection state changes
        Task { [weak self] in
            guard let self else { return }
            for await state in xmpp.connectionState {
                self.connectionState = state
                self.isLoggedIn = state.isConnected
            }
        }
    }

    // MARK: - Login / Logout

    func login(jid: String, password: String, host: String? = nil) async throws {
        try await connectUseCase.execute(jid: jid, password: password, host: host)
        self.myBareJID = jid.components(separatedBy: "/").first ?? jid
        KeychainHelper.save(jid: jid, password: password)
    }

    func logout() async {
        await connectUseCase.disconnect()
        isLoggedIn = false
        myBareJID  = ""
        KeychainHelper.clear()
    }

    // MARK: - Saved Credentials

    var savedCredentials: (jid: String, password: String)? {
        KeychainHelper.load()
    }
}

// MARK: - KeychainHelper

private enum KeychainHelper {
    private static let service = "com.xmppdemo.credentials"
    private static let jidKey  = "jid"
    private static let pwKey   = "password"

    static func save(jid: String, password: String) {
        saveString(jid,      account: jidKey)
        saveString(password, account: pwKey)
    }

    static func load() -> (jid: String, password: String)? {
        guard let jid = loadString(account: jidKey),
              let pw  = loadString(account: pwKey) else { return nil }
        return (jid, pw)
    }

    static func clear() {
        delete(account: jidKey)
        delete(account: pwKey)
    }

    private static func saveString(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadString(account: String) -> String? {
        var result: AnyObject?
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        SecItemCopyMatching(query as CFDictionary, &result)
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
