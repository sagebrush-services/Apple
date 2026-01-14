import Fluent
import Foundation
import Vapor

/// Projects that group assigned notations together.
///
/// This model represents projects in the matters schema, each with a unique codename
/// and containing multiple assigned notations. Projects serve as containers to organize
/// related legal work and notation assignments.
public final class Project: Model, @unchecked Sendable {
    public static let schema = "projects"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Field(key: "codename")
    public var codename: String

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
