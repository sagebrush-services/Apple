import Fluent
import Foundation
import Vapor

/// Join table between legal credentials and projects tracking disclosure periods.
///
/// This model represents disclosures in the matters schema, connecting legal credentials
/// to specific projects and tracking the time periods during which the disclosure
/// is active. Used for managing legal disclosure requirements and compliance.
public final class Disclosure: Model, @unchecked Sendable {
    public static let schema = "disclosures"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Parent(key: "credential_id")
    public var credential: Credential

    @Parent(key: "project_id")
    public var project: Project

    @Field(key: "disclosed_at")
    public var disclosedAt: Date

    @OptionalField(key: "end_disclosed_at")
    public var endDisclosedAt: Date?

    @Field(key: "active")
    public var active: Bool

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
