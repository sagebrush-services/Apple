import Fluent

struct CreateProjects: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Project.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("codename", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "codename")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(Project.schema).delete()
    }
}
