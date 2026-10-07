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
        }
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
        await loadLocalRoster()
        // Subscribe concurrently — each for-await loop runs in its own task.
        async let r: () = subscribeToRosterUpdates()
        async let p: () = subscribeToPresenceUpdates()
        async let c: () = subscribeToConnectionState()
        async let m: () = subscribeToInboundMessages()
        _ = await (r, p, c, m)
    }

    // MARK: - Local Load

    private func loadLocalRoster() async {
        do {
            contacts     = try await env.fetchRosterUseCase.execute()
            lastMessages = try await env.messageHistoryUseCase.lastMessages(myBareJID: env.myBareJID)
        } catch {
            // Non-fatal on first launch (empty store)
        }
    }

    // MARK: - XMPP Subscriptions
    // Each method is an async function that loops forever until its stream ends
    // or the parent task (from .task {}) is cancelled.

    private func subscribeToRosterUpdates() async {
        for await updated in env.xmpp.rosterUpdates {
            contacts = updated
            Task.detached(priority: .utility) { [store = env.rosterStore] in
                try? await store.upsert(updated)
            }
        }
    }

    private func subscribeToPresenceUpdates() async {
        for await (jid, status) in env.xmpp.presenceUpdates {
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

    private func subscribeToInboundMessages() async {
        for await message in env.xmpp.inboundMessages {
            lastMessages[message.fromJID] = message
            Task.detached(priority: .utility) { [store = env.messageStore] in
                try? await store.insert(message)
            }
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
