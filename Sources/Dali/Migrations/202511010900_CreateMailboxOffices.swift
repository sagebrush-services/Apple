import Fluent

struct CreateMailboxOffices: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema(MailboxOffice.schema)
            .field("id", .int32, .identifier(auto: true))
            .field("name", .string, .required)
            .field("address_line1", .string, .required)
            .field("address_line2", .string)
            .field("city", .string, .required)
            .field("state", .string, .required)
            .field("postal_code", .string, .required)
            .field("country", .string, .required)
            .field("mailbox_start", .int, .required)
            .field("mailbox_end", .int, .required)
            .field("capacity", .int)
            .field("inserted_at", .datetime, .required)
            .field("updated_at", .datetime)
            .create()

        let defaultOffice = MailboxOffice(
            id: 1,
            name: "Sagebrush Services Mailroom",
            addressLine1: "5150 Mae Anne Ave Ste 405-9000",
            city: "Reno",
            state: "NV",
            postalCode: "89523",
            mailboxStart: 9000,
            mailboxEnd: 9999,
            capacity: 1000
        )
        try await defaultOffice.create(on: database)
    }

    func revert(on database: Database) async throws {
        try await database.schema(MailboxOffice.schema).delete()
    }
}
