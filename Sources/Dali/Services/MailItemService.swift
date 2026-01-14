import Fluent
import Foundation
import Vapor

/// Handles CRUD and search operations for mailroom items.
public actor MailItemService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func list(
        mailboxID: Int32? = nil,
        entityID: Int32? = nil,
        status: MailItemStatus? = nil,
        limit: Int = 50
    ) async throws -> [MailItem] {
        var query = MailItem.query(on: database)
            .with(\.$mailbox)
            .with(\.$entity)
            .with(\.$uploader)
            .sort(\.$insertedAt, .descending)

        if let mailboxID {
            query = query.filter(\.$mailbox.$id == mailboxID)
        }
        if let entityID {
            query = query.filter(\.$entity.$id == entityID)
        }
        if let status {
            query = query.filter(\.$status == status)
        }

        return try await query.limit(limit).all()
    }

    public func create(
        mailboxID: Int32,
        entityID: Int32?,
        uploaderID: Int32?,
        storageKey: String,
        filename: String,
        contentType: String,
        status: MailItemStatus = .pendingVerification,
        notes: String? = nil,
        receivedAt: Date? = nil,
        aiConfidence: Double? = nil,
        aiNotes: String? = nil
    ) async throws -> MailItem {
        let item = MailItem()
        item.$mailbox.id = mailboxID
        item.$entity.id = entityID
        item.$uploader.id = uploaderID
        item.storageKey = storageKey
        item.filename = filename
        item.contentType = contentType
        item.status = status
        item.notes = notes
        item.receivedAt = receivedAt
        item.aiConfidence = aiConfidence
        item.aiNotes = aiNotes
        try await item.save(on: database)
        return item
    }

    public func update(
        id: Int32,
        status: MailItemStatus? = nil,
        entityID: Int32? = nil,
        notes: String? = nil,
        processedAt: Date? = nil,
        aiConfidence: Double? = nil,
        aiNotes: String? = nil
    ) async throws -> MailItem {
        guard let item = try await MailItem.find(id, on: database) else {
            throw Abort(.notFound, reason: "Mail item not found")
        }

        if let status {
            item.status = status
        }
        if let entityID {
            item.$entity.id = entityID
        }
        if let notes {
            item.notes = notes
        }
        if let processedAt {
            item.processedAt = processedAt
        }
        if let aiConfidence {
            item.aiConfidence = aiConfidence
        }
        if let aiNotes {
            item.aiNotes = aiNotes
        }

        try await item.save(on: database)
        return item
    }
}
