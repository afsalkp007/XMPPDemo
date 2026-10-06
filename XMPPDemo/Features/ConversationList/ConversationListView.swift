import SwiftUI

struct ConversationListView: View {
    @Environment(AppEnvironment.self) private var env
    // VM is initialised with .shared but receives the real env via .task below.
    @State private var vm = ConversationListViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    connectionBanner

                    Group {
                        if vm.filteredContacts.isEmpty {
                            emptyState
                        } else {
                            contactList
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: vm.filteredContacts.count)
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.bgSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $vm.searchQuery, prompt: "Search contacts")
            .navigationDestination(for: Contact.self) { contact in
                ChatView(contact: contact)
                    .environment(env)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await env.logout() }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.textSecondary)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    presencePill
                }
            }
        }
        // .task replaces the old Task { await bootstrap() } pattern:
        // the structured task is automatically cancelled when the view disappears.
        .task { await vm.start() }
    }

    // MARK: - Connection Banner

    @ViewBuilder
    private var connectionBanner: some View {
        if !vm.connectionState.isConnected {
            ConnectionBadgeView(state: vm.connectionState)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Presence Pill

    private var presencePill: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(vm.connectionState.isConnected ? Color.presenceOnline : Color.presenceOffline)
                .frame(width: 7, height: 7)
            Text(env.myBareJID.components(separatedBy: "@").first ?? env.myBareJID)
                .font(.appCaption)
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.bgElevated))
    }

    // MARK: - Contact List
    // Uses NavigationLink(value:) + .navigationDestination — the modern, non-deprecated API.

    private var contactList: some View {
        List {
            ForEach(vm.filteredContacts) { contact in
                NavigationLink(value: contact) {
                    ContactRowView(
                        contact: contact,
                        lastMessage: vm.lastMessages[contact.jid]
                    )
                }
                .listRowBackground(Color.bgSurface)
                .listRowSeparatorTint(Color.bgBorder)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(Color.brandCyan.opacity(0.4))

            VStack(spacing: 8) {
                Text(vm.searchQuery.isEmpty ? "No Contacts Yet" : "No Results")
                    .font(.appTitle2)
                    .foregroundStyle(.textPrimary)

                Text(
                    vm.searchQuery.isEmpty
                        ? "Your roster is empty.\nAdd contacts on your XMPP server."
                        : "No contacts match \"\(vm.searchQuery)\""
                )
                .font(.appSubheadline)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Contact Row

private struct ContactRowView: View {
    let contact: Contact
    let lastMessage: Message?

    var body: some View {
        HStack(spacing: 13) {
            AvatarView(contact: contact, size: 50)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(contact.displayName)
                        .font(.appHeadline)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let msg = lastMessage {
                        Text(msg.timestamp.conversationLabel)
                            .font(.appCaption2)
                            .foregroundStyle(.textTertiary)
                    }
                }

                HStack(spacing: 4) {
                    if let msg = lastMessage {
                        if msg.isOutgoing {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.textTertiary)
                        }
                        Text(msg.body)
                            .font(.appSubheadline)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                    } else {
                        Text(contact.presenceStatus.displayName)
                            .font(.appSubheadline)
                            .foregroundStyle(presenceColor(contact.presenceStatus))
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func presenceColor(_ status: PresenceStatus) -> Color {
        switch status {
        case .available: return .presenceOnline
        case .away:      return .presenceAway
        case .dnd:       return .presenceBusy
        case .xa:        return .presenceAway.opacity(0.7)
        case .offline:   return .textTertiary
        }
    }
}

#Preview {
    ConversationListView()
        .environment(AppEnvironment.shared)
}
