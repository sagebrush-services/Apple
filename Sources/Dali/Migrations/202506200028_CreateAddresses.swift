import Fluent
import FluentPostgresDriver
import SQLKit

struct CreateAddresses: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Address.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("entity_id", .int32, .references("entities", "id"))
            .field("person_id", .int32, .references("people", "id"))
            .field("street", .string, .required)
            .field("city", .string, .required)
            .field("state", .string)
            .field("zip", .string)
            .field("country", .string, .required)
            .field("is_verified", .bool, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .create()

    }

    func revert(on database: any Database) async throws {
        try await database.schema(Address.schema).delete()
    }
}
