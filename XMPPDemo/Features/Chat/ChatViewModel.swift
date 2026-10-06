import SwiftUI
import Observation

@MainActor
@Observable
final class ChatViewModel {

    // MARK: - Published State
    var messages:       [Message] = []
    var inputText       = ""
    var isSending       = false
    var errorMessage:   String? = nil
    var isTyping        = false      // Remote is typing
    var connectionState: ConnectionState = .disconnected

    // MARK: - Properties
    let contact: Contact
    private let env: AppEnvironment
    @ObservationIgnored private let taskBag = TaskBag()

    // Typing debounce
    private var typingTask: Task<Void, Never>?
    private var lastSentTyping = false

    var myBareJID: String { env.myBareJID }

    // MARK: - Init

    init(contact: Contact, env: AppEnvironment) {
        self.contact = contact
        self.env = env
        connectionState = env.connectionState
        Task { await bootstrap() }
    }

    convenience init(contact: Contact) {
        self.init(contact: contact, env: AppEnvironment.shared)
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        await loadHistory()
        subscribeToMessages()
        subscribeToChatStates()
        subscribeToConnectionState()
    }

    // MARK: - Load History

    private func loadHistory() async {
        do {
            let history = try await env.messageHistoryUseCase.execute(
                peerJID: contact.jid,
                myBareJID: env.myBareJID
            )
            messages = history
        } catch {
            // Empty history is fine
        }
    }

    // MARK: - Send

    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        inputText = ""
        isSending = true
        errorMessage = nil
        stopTypingIndicator()

        do {
            let sent = try await env.sendMessageUseCase.execute(to: contact.jid, body: trimmed)
            messages.append(sent)
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }

    // MARK: - Typing Indicator (XEP-0085)

    func onInputChanged() {
        guard !inputText.isEmpty else {
            stopTypingIndicator()
            return
        }
        sendTypingIfNeeded()
        debounceTypingStop()
    }

    private func sendTypingIfNeeded() {
        guard !lastSentTyping else { return }
        lastSentTyping = true
        Task { await env.xmpp.sendChatState(.composing, to: contact.jid) }
    }

    private func stopTypingIndicator() {
        guard lastSentTyping else { return }
        lastSentTyping = false
        Task { await env.xmpp.sendChatState(.paused, to: contact.jid) }
    }

    private func debounceTypingStop() {
        typingTask?.cancel()
        typingTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            stopTypingIndicator()
        }
    }

    // MARK: - Subscriptions

    private func subscribeToMessages() {
        let t = Task { [weak self] in
            guard let self else { return }
            for await message in env.xmpp.inboundMessages {
                let peerJID = self.contact.jid
                guard message.fromJID == peerJID || message.toJID == peerJID else { continue }
                self.messages.append(message)
                self.isTyping = false
                Task { try? await self.env.messageStore.insert(message) }
            }
        }
        taskBag.tasks.append(t)
    }

    private func subscribeToChatStates() {
        let t = Task { [weak self] in
            guard let self else { return }
            for await (from, state) in env.xmpp.chatStates {
                guard from == self.contact.jid else { continue }
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isTyping = (state == .composing)
                }
            }
        }
        taskBag.tasks.append(t)
    }

    private func subscribeToConnectionState() {
        let t = Task { [weak self] in
            guard let self else { return }
            for await state in env.xmpp.connectionState {
                self.connectionState = state
            }
        }
        taskBag.tasks.append(t)
    }
}

nonisolated private final class TaskBag {
    var tasks: [Task<Void, Never>] = []
    deinit { tasks.forEach { $0.cancel() } }
}
