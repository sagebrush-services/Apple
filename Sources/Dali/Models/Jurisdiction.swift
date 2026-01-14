import Fluent
import Foundation
import Vapor

/// Type of legal jurisdiction
public enum JurisdictionType: String, Codable, CaseIterable, Content, Sendable {
    case city = "city"
    case county = "county"
    case state = "state"
    case country = "country"
}

/// Represents a legal jurisdiction (state, country, etc.)
public final class Jurisdiction: Model, @unchecked Sendable {
    public static let schema = "jurisdictions"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Field(key: "name")
    public var name: String

    @Field(key: "code")
    public var code: String

    @Enum(key: "jurisdiction_type")
    public var jurisdictionType: JurisdictionType

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
