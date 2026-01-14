import Fluent

struct CreateCredentials: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Credential.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("person_id", .int32, .references("people", "id"), .required)
            .field("jurisdiction_id", .int32, .references("jurisdictions", "id"), .required)
            .field("license_number", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "jurisdiction_id", "license_number")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Credential.schema).delete()
    }
}
