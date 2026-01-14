import Fluent
import Foundation
import Vapor

// Enum for the role types
public enum PersonEntityRoleType: String, Codable, CaseIterable, Sendable {
    case admin = "admin"
}

// Represents the role a person has for a specific entity
public final class PersonEntityRole: Model, @unchecked Sendable {
    public static let schema = "person_entity_roles"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Parent(key: "person_id")
    public var person: Person

    @Parent(key: "entity_id")
    public var entity: Entity

    @Enum(key: "role")
    public var role: PersonEntityRoleType

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
