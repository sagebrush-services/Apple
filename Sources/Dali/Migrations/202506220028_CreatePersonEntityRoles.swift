import Fluent

struct CreatePersonEntityRoles: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(PersonEntityRole.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("person_id", .int32, .references("people", "id"), .required)
            .field("entity_id", .int32, .references("entities", "id"), .required)
            .field("role", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "person_id", "entity_id")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(PersonEntityRole.schema).delete()
    }
}
