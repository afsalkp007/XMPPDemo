import SwiftUI

struct ChatView: View {
    let contact: Contact
    @Environment(AppEnvironment.self) private var env
    @State private var vm: ChatViewModel

    init(contact: Contact) {
        self.contact = contact
        self.vm = ChatViewModel(contact: contact)
    }

    var body: some View {
        ZStack {
            Color.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Connection banner
                if !vm.connectionState.isConnected {
                    ConnectionBadgeView(state: vm.connectionState)
                        .padding(.top, 8)
                }

                // Message list
                messageList

                // Typing indicator
                if vm.isTyping {
                    typingIndicator
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                // Input bar
                ChatInputBar(
                    text: $vm.inputText,
                    isDisabled: !vm.connectionState.isConnected,
                    onSend: {
                        Task { await vm.sendMessage() }
                    },
                    onTextChange: {
                        vm.onInputChanged()
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.bgSurface, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar { navbarContent }
        .alert("Error", isPresented: .init(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(groupedMessages.enumerated()), id: \.offset) { _, group in
                        // Date section header
                        dateHeader(group.date)

                        ForEach(group.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                                .transition(.asymmetric(
                                    insertion: .push(from: message.isOutgoing ? .trailing : .leading).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }

                    // Anchor for auto-scroll
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.vertical, 12)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: vm.messages.count)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        }
    }

    // MARK: - Date Section Header

    private func dateHeader(_ date: Date) -> some View {
        Text(date.conversationLabel)
            .font(.appCaption)
            .foregroundStyle(.textTertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.bgElevated.opacity(0.8)))
            .padding(.vertical, 8)
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            AvatarView(contact: vm.contact, size: 28)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.textTertiary)
                        .frame(width: 6, height: 6)
                        .phaseAnimator([0.0, -4.0, 0.0]) { view, phase in
                            view.offset(y: phase)
                        } animation: { _ in
                            .easeInOut(duration: 0.5)
                                .delay(Double(i) * 0.15)
                                .repeatForever(autoreverses: true)
                        }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.bubbleIn)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    // MARK: - Navigation Bar

    @ToolbarContentBuilder
    private var navbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(vm.contact.displayName)
                    .font(.appHeadline)
                    .foregroundStyle(.textPrimary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(presenceColor(vm.contact.presenceStatus))
                        .frame(width: 6, height: 6)
                    Text(vm.contact.presenceStatus.displayName)
                        .font(.appCaption2)
                        .foregroundStyle(.textSecondary)
                }
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            AvatarView(contact: vm.contact, size: 34)
        }
    }

    // MARK: - Grouped Messages

    private var groupedMessages: [(date: Date, messages: [Message])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: vm.messages) { msg in
            calendar.startOfDay(for: msg.timestamp)
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (date: $0.key, messages: $0.value.sorted { $0.timestamp < $1.timestamp }) }
    }

    // MARK: - Helpers

    private func presenceColor(_ status: PresenceStatus) -> Color {
        switch status {
        case .available: return .presenceOnline
        case .away:      return .presenceAway
        case .dnd:       return .presenceBusy
        case .xa:        return .presenceAway.opacity(0.7)
        case .offline:   return .presenceOffline
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(contact: Contact(jid: "alice@jabber.org", name: "Alice", presenceStatus: .available))
            .environment(AppEnvironment.shared)
    }
}
