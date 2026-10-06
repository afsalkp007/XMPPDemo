import Foundation
import SwiftData

// MARK: - Delivery Status

nonisolated enum DeliveryStatus: String, Codable, Equatable, Sendable {
    case sending
    case sent
    case delivered
    case read
    case failed

    var systemImage: String {
        switch self {
        case .sending:   return "clock"
        case .sent:      return "checkmark"
        case .delivered: return "checkmark.circle"
        case .read:      return "checkmark.circle.fill"
        case .failed:    return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Domain Model

/// Immutable, Sendable message value type.
nonisolated struct Message: Identifiable, Equatable, Sendable {
    let id: String
    let fromJID: String
    let toJID: String
    let body: String
    let timestamp: Date
    var deliveryStatus: DeliveryStatus
    let isOutgoing: Bool

    init(
        id: String = UUID().uuidString,
        fromJID: String,
        toJID: String,
        body: String,
        timestamp: Date = .now,
        deliveryStatus: DeliveryStatus = .sending,
        isOutgoing: Bool
    ) {
        self.id = id
        self.fromJID = fromJID
        self.toJID = toJID
        self.body = body
        self.timestamp = timestamp
        self.deliveryStatus = deliveryStatus
        self.isOutgoing = isOutgoing
    }

    /// Returns the JID of the other party in this conversation.
    func peerJID(myBareJID: String) -> String {
        isOutgoing ? toJID : fromJID
    }

    /// Bare JID of the peer (strips resource).
    func barePeerJID(myBareJID: String) -> String {
        peerJID(myBareJID: myBareJID).components(separatedBy: "/").first ?? peerJID(myBareJID: myBareJID)
    }
}

// MARK: - SwiftData Persistence Record

@Model
final class MessageRecord {
    @Attribute(.unique) var id: String
    var fromJID: String
    var toJID: String
    var body: String
    var timestamp: Date
    var deliveryStatusRaw: String
    var isOutgoing: Bool

    init(from message: Message) {
        self.id = message.id
        self.fromJID = message.fromJID
        self.toJID = message.toJID
        self.body = message.body
        self.timestamp = message.timestamp
        self.deliveryStatusRaw = message.deliveryStatus.rawValue
        self.isOutgoing = message.isOutgoing
    }

    var deliveryStatus: DeliveryStatus {
        get { DeliveryStatus(rawValue: deliveryStatusRaw) ?? .sent }
        set { deliveryStatusRaw = newValue.rawValue }
    }

    func toDomainModel() -> Message {
        Message(
            id: id,
            fromJID: fromJID,
            toJID: toJID,
            body: body,
            timestamp: timestamp,
            deliveryStatus: deliveryStatus,
            isOutgoing: isOutgoing
        )
    }
}
