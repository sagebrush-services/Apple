import Fluent
import FluentPostgresDriver
import SQLKit

struct CreateBlobs: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Blob.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("object_storage_url", .string, .required)
            .field("referenced_by", .string, .required)
            .field("referenced_by_id", .int32, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "object_storage_url")
            .create()

    }

    func revert(on database: any Database) async throws {
        try await database.schema(Blob.schema).delete()
    }
}
