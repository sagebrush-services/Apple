import Fluent
import Foundation
import Vapor

/// Relationship logs for legal matters linking projects with legal credentials.
///
/// This model represents relationship logs in the matters schema, tracking
/// relationship information for legal matters.
public final class RelationshipLog: Model, @unchecked Sendable {
    public static let schema = "relationship_logs"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Parent(key: "project_id")
    public var project: Project

    @Parent(key: "credential_id")
    public var credential: Credential

    @Field(key: "body")
    public var body: String

    @Field(key: "relationships")
    public var relationships: [String: String]?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(projectID: Int32, credentialID: Int32, body: String, relationships: [String: String]? = nil) {
        self.$project.id = projectID
        self.$credential.id = credentialID
        self.body = body
        self.relationships = relationships
    }
}
