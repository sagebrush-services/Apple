import Fluent

struct EnhanceFormationTracking: AsyncMigration {
    func prepare(on database: Database) async throws {
        // SQLite doesn't support adding multiple columns in one ALTER TABLE
        // Add each field separately
        try await database.schema(FlowInstanceRecord.schema)
            .field("mailbox_id", .int32, .references(Mailbox.schema, "id"))
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .field("generated_document_url", .string)
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .field("notarization_provider_id", .string)
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .field("paid_at", .datetime)
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .field("filed_at", .datetime)
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .field("formed_at", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        // SQLite doesn't support dropping multiple columns in one ALTER TABLE
        // Drop each field separately, in reverse order (last added first)
        try await database.schema(FlowInstanceRecord.schema)
            .deleteField("formed_at")
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .deleteField("filed_at")
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .deleteField("paid_at")
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .deleteField("notarization_provider_id")
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .deleteField("generated_document_url")
            .update()

        try await database.schema(FlowInstanceRecord.schema)
            .deleteField("mailbox_id")
            .update()
    }
}
