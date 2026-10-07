import Foundation
import SwiftData

// MARK: - Presence

/// Maps directly to XMPP `<show/>` element values plus `offline` for unavailable presence.
nonisolated enum PresenceStatus: String, Codable, Equatable, Sendable {
    case available
    case away
    case dnd        // Do Not Disturb (<show>dnd</show>)
    case xa         // Extended Away  (<show>xa</show>)
    case offline    // <presence type="unavailable"/>

    var displayName: String {
        switch self {
        case .available: return "Online"
        case .away:      return "Away"
        case .dnd:       return "Busy"
        case .xa:        return "Extended Away"
        case .offline:   return "Offline"
        }
    }

    /// Derives presence from the optional XMPP `<show>` text content.
    static func from(xmppShow: String?, type: String?) -> PresenceStatus {
        if type == "unavailable" { return .offline }
        switch xmppShow?.lowercased() {
        case "away": return .away
        case "dnd":  return .dnd
        case "xa":   return .xa
        default:     return .available
        }
    }
}

// MARK: - Domain Model

/// Immutable value type representing a roster contact.
nonisolated struct Contact: Identifiable, Equatable, Hashable, Sendable {
    var id: String { jid }

    let jid: String
    var name: String
    var presenceStatus: PresenceStatus
    var statusMessage: String?
    var lastSeen: Date?

    // MARK: Derived

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? localPart : trimmed
    }

    /// e.g. "alice" from "alice@jabber.org"
    var localPart: String {
        jid.components(separatedBy: "@").first ?? jid
    }

    /// Up to two initials, used in AvatarView
    var initials: String {
        let words = displayName.split(separator: " ").prefix(2)
        return words.map { String($0.prefix(1)).uppercased() }.joined()
    }

    /// Stable hue for avatar background (0–1)
    var avatarHue: Double {
        let hash = abs(jid.hashValue)
        return Double(hash % 360) / 360.0
    }

}

// MARK: - SwiftData Persistence Record

/// SwiftData-backed contact record. Use `Contact` (the value type) in domain code.
@Model
final class ContactRecord {
    @Attribute(.unique) var jid: String
    var name: String
    var presenceStatusRaw: String
    var statusMessage: String?
    var lastSeen: Date?

    init(jid: String, name: String = "", presenceStatus: PresenceStatus = .offline) {
        self.jid = jid
        self.name = name
        self.presenceStatusRaw = presenceStatus.rawValue
    }

    var presenceStatus: PresenceStatus {
        get { PresenceStatus(rawValue: presenceStatusRaw) ?? .offline }
        set { presenceStatusRaw = newValue.rawValue }
    }

    func toDomainModel() -> Contact {
        Contact(
            jid: jid,
            name: name,
            presenceStatus: presenceStatus,
            statusMessage: statusMessage,
            lastSeen: lastSeen
        )
    }
}
