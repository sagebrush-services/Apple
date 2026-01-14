import Fluent

struct CreateFlowSteps: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(FlowStepRecord.schema)
            .id()
            .field("instance_id", .uuid, .required, .references(FlowInstanceRecord.schema, "id", onDelete: .cascade))
            .field("state_id", .string, .required)
            .field("question_code", .string, .required)
            .field("context_tokens", .array(of: .string), .required)
            .field("answer_payload", .json, .required)
            .field("answer_type", .string, .required)
            .field("actor_role", .string, .required)
            .field("actor_user_id", .int32)
            .field("created_at", .datetime, .required)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(FlowStepRecord.schema).delete()
    }
}
