import Fluent
import Foundation
import Vapor

/// Represents a type of legal entity
public final class EntityType: Model, @unchecked Sendable {
    public static let schema = "entity_types"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Parent(key: "jurisdiction_id")
    public var jurisdiction: Jurisdiction

    @Field(key: "name")
    public var name: String

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}

extension EntityType: Content {}
