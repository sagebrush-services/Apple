import Fluent
import FluentPostgresDriver
import SQLKit

struct CreateQuestions: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(Question.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("prompt", .string, .required)
            .field("question_type", .string, .required)
            .field("code", .string, .required)
            .field("help_text", .string)
            .field("choices", .dictionary)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .unique(on: "code")
            .create()

    }

    func revert(on database: any Database) async throws {
        try await database.schema(Question.schema).delete()
    }
}
