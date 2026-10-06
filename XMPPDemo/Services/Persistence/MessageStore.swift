import Foundation
import SwiftData

/// Thread-safe message persistence using a SwiftData ModelActor.
/// All reads/writes happen off the main thread.
@ModelActor
actor MessageStore {

    // MARK: - Write

    func insert(_ message: Message) throws {
        let record = MessageRecord(from: message)
        modelContext.insert(record)
        try modelContext.save()
    }

    func insert(_ messages: [Message]) throws {
        messages.forEach { modelContext.insert(MessageRecord(from: $0)) }
        try modelContext.save()
    }

    func updateDeliveryStatus(id: String, status: DeliveryStatus) throws {
        let descriptor = FetchDescriptor<MessageRecord>(
            predicate: #Predicate { $0.id == id }
        )
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.deliveryStatus = status
        try modelContext.save()
    }

    // MARK: - Read

    /// Returns all messages in a conversation (both directions) sorted ascending.
    func messages(for peerJID: String, myBareJID: String, limit: Int = 100) throws -> [Message] {
        let descriptor = FetchDescriptor<MessageRecord>(
            predicate: #Predicate<MessageRecord> {
                ($0.fromJID == peerJID && $0.toJID == myBareJID) ||
                ($0.fromJID == myBareJID && $0.toJID == peerJID)
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomainModel() }
    }

    /// Returns the last message per unique peer JID — used for conversation list.
    func lastMessages(myBareJID: String) throws -> [String: Message] {
        let descriptor = FetchDescriptor<MessageRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let all = try modelContext.fetch(descriptor)
        var result: [String: Message] = [:]
        for record in all {
            let peer = record.isOutgoing ? record.toJID : record.fromJID
            if result[peer] == nil {
                result[peer] = record.toDomainModel()
            }
        }
        return result
    }

    // MARK: - Delete

    func deleteAll() throws {
        try modelContext.delete(model: MessageRecord.self)
        try modelContext.save()
    }
}
