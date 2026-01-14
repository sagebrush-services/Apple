import Fluent
import FluentPostgresDriver
import SQLKit

struct CreateUsers: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(User.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("sub", .string)
            .field("role", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("person_id", .int32, .references("people", "id"), .required)
            .unique(on: "sub")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(User.schema).delete()
    }
}
