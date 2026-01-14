import Fluent

struct CreateFlowInstances: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema(FlowInstanceRecord.schema)
            .id()
            .field("notation_code", .string, .required)
            .field("kind", .string, .required)
            .field("status", .string, .required)
            .field("current_state", .string)
            .field("progress_stage", .string)
            .field("progress_percent", .double)
            .field("respondent_entity_id", .int32)
            .field("respondent_person_id", .int32)
            .field("user_id", .int32, .required, .references(User.schema, "id"))
            .field("created_at", .datetime, .required)
            .field("updated_at", .datetime, .required)
            .field("completed_at", .datetime)
            .create()
    }

    func revert(on database: any Database) async throws {
        try await database.schema(FlowInstanceRecord.schema).delete()
    }
}
