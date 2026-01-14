import Fluent

struct CreatePeople: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Person.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "email")
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("people").delete()
    }
}
