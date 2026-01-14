import Fluent

struct CreateMailItems: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(MailItem.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("mailbox_id", .int32, .required, .references(Mailbox.schema, "id"))
            .field("entity_id", .int32, .references(Entity.schema, "id"))
            .field("uploader_id", .int32, .references(User.schema, "id"))
            .field("storage_key", .string, .required)
            .field("filename", .string, .required)
            .field("content_type", .string, .required)
            .field("status", .string, .required)
            .field("notes", .string)
            .field("received_at", .datetime)
            .field("processed_at", .datetime)
            .field("ai_confidence", .double)
            .field("ai_notes", .string)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime)
            .unique(on: "storage_key")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema(MailItem.schema).delete()
    }
}
