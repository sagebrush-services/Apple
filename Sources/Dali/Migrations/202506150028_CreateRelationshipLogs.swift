import Fluent

struct CreateRelationshipLogs: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(RelationshipLog.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("project_id", .int32, .references("projects", "id"), .required)
            .field("credential_id", .int32, .references("credentials", "id"), .required)
            .field("body", .string, .required)
            .field("relationships", .dictionary, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(RelationshipLog.schema).delete()
    }
}
