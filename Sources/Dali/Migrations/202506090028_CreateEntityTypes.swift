import Fluent

struct CreateEntityTypes: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(EntityType.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("name", .string, .required)
            .field("jurisdiction_id", .int32, .references("jurisdictions", "id"), .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "name", "jurisdiction_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(EntityType.schema).delete()
    }
}
