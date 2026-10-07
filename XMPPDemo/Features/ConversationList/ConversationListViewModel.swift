import SwiftUI
import Observation

@MainActor
@Observable
final class ConversationListViewModel {

    // MARK: - Published State
    var contacts:     [Contact]         = []
    var lastMessages: [String: Message] = [:]
    var searchQuery                      = ""
    var connectionState: ConnectionState = .disconnected

    // MARK: - Derived
    var filteredContacts: [Contact] {
        let sorted = contacts.sorted {
            presenceOrder($0.presenceStatus) < presenceOrder($1.presenceStatus)
        }.filter { $0.jid != env.myBareJID }
        guard !searchQuery.isEmpty else { return sorted }
        return sorted.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.jid.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    // MARK: - Dependencies
    private let env: AppEnvironment
    // Strong references so cancellation happens when the VM is deallocated.
    private var streamTasks: [Task<Void, Never>] = []

    init(env: AppEnvironment) {
        self.env = env
        connectionState = env.connectionState
    }

    convenience init() {
        self.init(env: AppEnvironment.shared)
    }

    // MARK: - Lifecycle (called from .task modifier — auto-cancelled on disappear)

    func start() async {
        // Start listening to notifications FIRST so we don't miss anything
        let subscriptionTask = Task {
            async let r: () = subscribeToRosterUpdates()
            async let p: () = subscribeToPresenceUpdates()
            async let c: () = subscribeToConnectionState()
            async let m: () = subscribeToMessages()
            _ = await (r, p, c, m)
        }
        
        // Give AppEnvironment a brief moment to finish saving the initial 
        // burst of offline messages and roster pushes to the database
        try? await Task.sleep(for: .milliseconds(300))
        
        await loadLocalRoster()
        
        await subscriptionTask.value
    }

    func reload() async {
        await loadLocalRoster()
    }

    // MARK: - Local Load

    private func loadLocalRoster() async {
        do {
            let dbContacts = try await env.fetchRosterUseCase.execute()
            
            // Merge DB contacts with any live presence we might have already received
            var merged = dbContacts
            for i in merged.indices {
                if let live = self.contacts.first(where: { $0.jid == merged[i].jid }), live.presenceStatus != .offline {
                    merged[i].presenceStatus = live.presenceStatus
                }
            }
            contacts = merged
            
            lastMessages = try await env.messageHistoryUseCase.lastMessages(myBareJID: env.myBareJID)
        } catch {
            // Non-fatal on first launch (empty store)
        }
    }

    // MARK: - XMPP Subscriptions
    // Each method is an async function that loops forever until its stream ends
    // or the parent task (from .task {}) is cancelled.

    private func subscribeToRosterUpdates() async {
        for await notification in NotificationCenter.default.notifications(named: .xmppRosterUpdate) {
            guard let updated = notification.userInfo?["contacts"] as? [Contact] else { continue }
            contacts = updated
        }
    }

    private func subscribeToPresenceUpdates() async {
        for await notification in NotificationCenter.default.notifications(named: .xmppPresenceUpdate) {
            guard let jid = notification.userInfo?["jid"] as? String,
                  let status = notification.userInfo?["status"] as? PresenceStatus else { continue }
            if let idx = contacts.firstIndex(where: { $0.jid == jid }) {
                contacts[idx].presenceStatus = status
            }
            Task.detached(priority: .utility) { [store = env.rosterStore] in
                try? await store.updatePresence(jid: jid, status: status)
            }
        }
    }

    private func subscribeToConnectionState() async {
        // Observe the @Observable env.connectionState property rather than
        // re-consuming xmpp.connectionState (single-consumer AsyncStream).
        while !Task.isCancelled {
            connectionState = env.connectionState
            
            // Safety net: When we successfully connect, the server instantly flushes offline messages.
            // We wait 0.5s for AppEnvironment to finish saving them to SwiftData, then reload the UI
            // to guarantee no messages fell into the async timing gap during app launch.
            if connectionState == .connected {
                try? await Task.sleep(for: .milliseconds(500))
                await loadLocalRoster()
            }
            
            // Suspend until env.connectionState changes, then loop.
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                withObservationTracking {
                    _ = env.connectionState
                } onChange: {
                    cont.resume()
                }
            }
        }
    }

    private func subscribeToMessages() async {
        async let i: () = processInbound()
        async let o: () = processOutbound()
        _ = await (i, o)
    }

    private func processInbound() async {
        for await notification in NotificationCenter.default.notifications(named: .didInsertMessage) {
            guard let message = notification.userInfo?["message"] as? Message else { continue }
            lastMessages[message.fromJID] = message
        }
    }

    private func processOutbound() async {
        for await notification in NotificationCenter.default.notifications(named: .xmppOutboundMessage) {
            guard let message = notification.userInfo?["message"] as? Message else { continue }
            lastMessages[message.toJID] = message
            // Outbound is already persisted by SendMessageUseCase, no need to insert here
        }
    }

    // MARK: - Helpers

    private func presenceOrder(_ status: PresenceStatus) -> Int {
        switch status {
        case .available: return 0
        case .away:      return 1
        case .dnd:       return 2
        case .xa:        return 3
        case .offline:   return 4
        }
    }
}
