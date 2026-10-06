import Foundation
import SwiftData

/// Thread-safe roster persistence using a SwiftData ModelActor.
@ModelActor
actor RosterStore {

    // MARK: - Write

    /// Upserts a contact — inserts if new, updates existing record.
    func upsert(_ contact: Contact) throws {
        let jid = contact.jid
        let descriptor = FetchDescriptor<ContactRecord>(
            predicate: #Predicate { $0.jid == jid }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name              = contact.name
            existing.presenceStatus    = contact.presenceStatus
            existing.statusMessage     = contact.statusMessage
            existing.lastSeen          = contact.lastSeen
        } else {
            let record = ContactRecord(jid: contact.jid, name: contact.name, presenceStatus: contact.presenceStatus)
            record.statusMessage = contact.statusMessage
            record.lastSeen      = contact.lastSeen
            modelContext.insert(record)
        }
        try modelContext.save()
    }

    func upsert(_ contacts: [Contact]) throws {
        try contacts.forEach { try upsert($0) }
    }

    func updatePresence(jid: String, status: PresenceStatus) throws {
        let descriptor = FetchDescriptor<ContactRecord>(
            predicate: #Predicate { $0.jid == jid }
        )
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.presenceStatus = status
        record.lastSeen = status == .offline ? .now : record.lastSeen
        try modelContext.save()
    }

    // MARK: - Read

    func allContacts() throws -> [Contact] {
        let descriptor = FetchDescriptor<ContactRecord>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.toDomainModel() }
    }

    func contact(jid: String) throws -> Contact? {
        let descriptor = FetchDescriptor<ContactRecord>(
            predicate: #Predicate { $0.jid == jid }
        )
        return try modelContext.fetch(descriptor).first?.toDomainModel()
    }

    // MARK: - Delete

    func deleteAll() throws {
        try modelContext.delete(model: ContactRecord.self)
        try modelContext.save()
    }
}
