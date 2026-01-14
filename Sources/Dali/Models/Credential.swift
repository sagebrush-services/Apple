import Fluent
import Vapor

public final class Credential: Model, @unchecked Sendable {
    public static let schema = "credentials"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Parent(key: "person_id")
    public var person: Person

    @Parent(key: "jurisdiction_id")
    public var jurisdiction: Jurisdiction

    @Field(key: "license_number")
    public var licenseNumber: String

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
