import Fluent
import Foundation
import Vapor

/// Represents a physical mailbox office that can host customer mailboxes.
public final class MailboxOffice: Model, @unchecked Sendable {
    public static let schema = "mailbox_offices"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Field(key: "name")
    public var name: String

    @Field(key: "address_line1")
    public var addressLine1: String

    @Field(key: "address_line2")
    public var addressLine2: String?

    @Field(key: "city")
    public var city: String

    @Field(key: "state")
    public var state: String

    @Field(key: "postal_code")
    public var postalCode: String

    @Field(key: "country")
    public var country: String

    @Field(key: "mailbox_start")
    public var mailboxStart: Int

    @Field(key: "mailbox_end")
    public var mailboxEnd: Int

    @Field(key: "capacity")
    public var capacity: Int?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

    public init(
        id: Int32? = nil,
        name: String,
        addressLine1: String,
        addressLine2: String? = nil,
        city: String,
        state: String,
        postalCode: String,
        country: String = "USA",
        mailboxStart: Int,
        mailboxEnd: Int,
        capacity: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
        self.mailboxStart = mailboxStart
        self.mailboxEnd = mailboxEnd
        self.capacity = capacity
    }
}
