import SwiftUI

/// Renders a contact's initials over a deterministic hue background.
struct AvatarView: View {
    let contact: Contact
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: contact.avatarHue, saturation: 0.65, brightness: 0.75),
                            Color(hue: contact.avatarHue, saturation: 0.80, brightness: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text(contact.initials.isEmpty ? "?" : contact.initials)
                .font(.system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            PresenceDot(status: contact.presenceStatus, size: size * 0.30)
                .offset(x: 1, y: 1)
        }
    }
}

// MARK: - Presence Dot

struct PresenceDot: View {
    let status: PresenceStatus
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(presenceColor)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(Color.bgPrimary, lineWidth: size * 0.18))
    }

    private var presenceColor: Color {
        switch status {
        case .available: return .presenceOnline
        case .away:      return .presenceAway
        case .dnd:       return .presenceBusy
        case .xa:        return .presenceAway.opacity(0.6)
        case .offline:   return .presenceOffline
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        AvatarView(contact: Contact(jid: "alice@jabber.org",  name: "Alice",       presenceStatus: .available))
        AvatarView(contact: Contact(jid: "bob@jabber.org",    name: "Bob Smith",   presenceStatus: .away))
        AvatarView(contact: Contact(jid: "charlie@xmpp.com",  name: "",            presenceStatus: .offline))
    }
    .padding()
    .background(Color.bgPrimary)
}
