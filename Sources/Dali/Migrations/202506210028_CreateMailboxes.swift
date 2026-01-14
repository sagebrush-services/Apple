import Fluent

struct CreateMailboxes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Mailbox.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("address_id", .int32, .references("addresses", "id"), .required)
            .field("mailbox_number", .int, .required)
            .field("is_active", .bool, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "address_id", "mailbox_number")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Mailbox.schema).delete()
    }
}
