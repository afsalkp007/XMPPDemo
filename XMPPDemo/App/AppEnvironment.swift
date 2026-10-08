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
    let mediaUploadUseCase:    MediaUploadUseCase

    // MARK: - Session State (observed by views automatically via @Observable)

    var connectionState: ConnectionState = .disconnected
    var myBareJID: String = ""
    var isLoggedIn: Bool = false
    private var shouldReconnect: Bool = false

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
        mediaUploadUseCase    = MediaUploadUseCase(xmpp: xmpp)

        // Observe XMPP connection state changes
        Task { [weak self] in
            guard let self else { return }
            for await state in xmpp.connectionState {
                print("[XMPP] connectionState → \(state)")
                self.connectionState = state
                
                // Auto-reconnect logic
                if self.shouldReconnect && !state.isConnected {
                    if case .disconnected = state {
                        Task { await self.reconnect() }
                    } else if case .failed = state {
                        Task { await self.reconnect() }
                    }
                }
            }
            print("[XMPP] connectionState stream ended")
        }

        // ALWAYS listen for inbound messages and persist them to SwiftData.
        // Using synchronous addObserver ensures we don't miss offline messages
        // that arrive immediately upon connection, avoiding AsyncStream setup race conditions.
        NotificationCenter.default.addObserver(forName: .xmppInboundMessage, object: nil, queue: nil) { [weak self] notification in
            guard let message = notification.userInfo?["message"] as? Message else { return }
            Task {
                try? await self?.messageStore.insert(message)
                NotificationCenter.default.post(name: .didInsertMessage, object: nil, userInfo: ["message": message])
            }
        }
        
        NotificationCenter.default.addObserver(forName: .xmppRosterUpdate, object: nil, queue: nil) { [weak self] notification in
            guard let contacts = notification.userInfo?["contacts"] as? [Contact] else { return }
            Task { try? await self?.rosterStore.upsert(contacts) }
        }
        
        NotificationCenter.default.addObserver(forName: .xmppPresenceUpdate, object: nil, queue: nil) { [weak self] notification in
            guard let jid = notification.userInfo?["jid"] as? String,
                  let status = notification.userInfo?["status"] as? PresenceStatus else { return }
            Task { try? await self?.rosterStore.updatePresence(jid: jid, status: status) }
        }
        
        NotificationCenter.default.addObserver(forName: .xmppMessageDelivered, object: nil, queue: nil) { [weak self] notification in
            guard let messageID = notification.userInfo?["messageID"] as? String else { return }
            Task { try? await self?.messageStore.updateDeliveryStatus(id: messageID, status: .delivered) }
        }
    }

    // MARK: - Login / Logout

    func login(jid: String, password: String, host: String? = nil) async throws {
        try await connectUseCase.execute(jid: jid, password: password, host: host)

        // Wait for connectionState — kept up-to-date by the init Task that owns
        // the AsyncStream — to reach a terminal state.
        //
        // We use withObservationTracking (iOS 17 Observation framework) to react
        // to every @Observable connectionState change event-driven, with no polling.
        //
        // seenTransition: ignore the initial .disconnected idle value; only treat
        // .disconnected as an error after we've seen .connecting (real attempt started).
        var seenTransition = false
        try await waitForConnection(jid: jid, password: password, seenTransition: &seenTransition)
    }

    /// Recursively waits for `connectionState` to reach `.connected` or a terminal
    /// failure, using `withObservationTracking` for event-driven observation.
    private func waitForConnection(
        jid: String,
        password: String,
        seenTransition: inout Bool,
        deadline: Date = Date.now.addingTimeInterval(30)
    ) async throws {
        guard Date.now < deadline else {
            print("[XMPP] waitForConnection: TIMEOUT")
            throw XMPPError.timeout
        }

        print("[XMPP] waitForConnection: checking state = \(connectionState), seenTransition=\(seenTransition)")

        // Check current state first.
        switch connectionState {
        case .connected:
            print("[XMPP] waitForConnection: ✅ connected")
            myBareJID = jid.components(separatedBy: "/").first ?? jid
            KeychainHelper.save(jid: jid, password: password)
            isLoggedIn = true
            shouldReconnect = true
            return

        case .failed(let err):
            print("[XMPP] waitForConnection: ❌ failed — \(err)")
            throw XMPPError.connectionFailed(err)

        case .disconnected:
            if seenTransition {
                // We were connecting but the server dropped us.
                print("[XMPP] waitForConnection: ❌ disconnected after transition")
                throw XMPPError.disconnected
            }
            // Still the initial idle value — fall through and wait for next change.
            print("[XMPP] waitForConnection: still idle .disconnected, waiting…")

        case .connecting, .reconnecting:
            seenTransition = true
            print("[XMPP] waitForConnection: in-progress (\(connectionState)), waiting…")
        }

        // Suspend until connectionState changes, then re-evaluate.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            // withObservationTracking fires onChange exactly once when any tracked
            // property (connectionState here) is mutated.
            withObservationTracking {
                _ = self.connectionState   // register the dependency
            } onChange: {
                print("[XMPP] withObservationTracking: onChange fired")
                cont.resume()              // wake up on next change
            }
        }

        // Recurse (tail-call style) to re-check the updated value.
        try await waitForConnection(jid: jid, password: password,
                                    seenTransition: &seenTransition, deadline: deadline)
    }

    func logout() async {
        shouldReconnect = false
        await connectUseCase.disconnect()
        isLoggedIn = false
        myBareJID  = ""
        KeychainHelper.clear()
    }

    private func reconnect() async {
        guard shouldReconnect, let creds = savedCredentials else { return }
        try? await Task.sleep(for: .seconds(2)) // Backoff
        // Check if we still need to reconnect after waiting
        guard shouldReconnect, !connectionState.isConnected else { return }
        try? await connectUseCase.execute(jid: creds.jid, password: creds.password, host: nil)
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
