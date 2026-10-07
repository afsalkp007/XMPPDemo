import SwiftUI

struct ConversationListView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var vm = ConversationListViewModel()
    @State private var showNewChat = false
    @State private var adHocContact: Contact? = nil

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
            // Ad-hoc destination (new chat by JID)
            .navigationDestination(item: $adHocContact) { contact in
                ChatView(contact: contact)
                    .environment(env)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        // New chat — type any JID
                        Button {
                            showNewChat = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .foregroundStyle(Color.brandCyan)
                        }
                        .accessibilityIdentifier("newChatButton")

                        Button {
                            Task { await env.logout() }
                        } label: {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(.textSecondary)
                        }
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    presencePill
                }
            }
        }
        .task { await vm.start() }
        .sheet(isPresented: $showNewChat) {
            NewChatSheet { jid in
                Task { await env.xmpp.addContact(jid: jid) }
                let contact = Contact(jid: jid, name: "", presenceStatus: .offline)
                adHocContact = contact
                showNewChat = false
            }
        }
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
        Button(action: {}) {
            HStack(spacing: 5) {
                Circle()
                    .fill(vm.connectionState.isConnected ? Color.presenceOnline : Color.presenceOffline)
                    .frame(width: 7, height: 7)
                Text(env.myBareJID.components(separatedBy: "@").first ?? env.myBareJID)
                    .font(.appCaption)
                    .foregroundStyle(.textSecondary)
            }
        }
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

// MARK: - New Chat Sheet

private struct NewChatSheet: View {
    let onStart: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var jid = ""

    private var isValid: Bool {
        let t = jid.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.count > 3
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.bgPrimary.ignoresSafeArea()

                VStack(spacing: 28) {
                    // Icon
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.brandCyan, Color.brandCyan.opacity(0.5)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 32)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recipient JID")
                            .font(.appCaption)
                            .foregroundStyle(.textSecondary)
                            .padding(.horizontal, 4)

                        TextField("user@domain.com", text: $jid)
                            .font(.appBody)
                            .foregroundStyle(.textPrimary)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isValid ? Color.brandCyan.opacity(0.5) : Color.bgBorder, lineWidth: 1)
                            )
                            .accessibilityIdentifier("newChatJIDField")
                    }
                    .padding(.horizontal, 24)

                    Button {
                        let trimmed = jid.trimmingCharacters(in: .whitespaces).lowercased()
                        onStart(trimmed)
                    } label: {
                        Text("Start Chat")
                            .font(.appHeadline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(
                                isValid
                                    ? LinearGradient(colors: [Color.brandCyan, Color.brandCyan.opacity(0.7)],
                                                     startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.bgElevated, Color.bgElevated],
                                                     startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 24)
                    }
                    .disabled(!isValid)
                    .accessibilityIdentifier("startChatButton")
                    .animation(.easeInOut(duration: 0.2), value: isValid)

                    Spacer()
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgSurface, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.textSecondary)
                }
            }
        }
    }
}
