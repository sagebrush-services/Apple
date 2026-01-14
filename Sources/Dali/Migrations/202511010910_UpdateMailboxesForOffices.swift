import Fluent
import SQLKit

#if canImport(SQLiteKit)
import SQLiteKit
#endif

struct UpdateMailboxesForOffices: AsyncMigration {
    func prepare(on database: Database) async throws {
        // SQLite doesn't support adding multiple columns in one ALTER TABLE
        // Add each field separately
        try await addColumnIfNeeded(
            sql: """
                ALTER TABLE "mailboxes"
                ADD COLUMN IF NOT EXISTS "office_id" INT
                REFERENCES "mailbox_offices" ("id")
                ON DELETE NO ACTION
                ON UPDATE NO ACTION
                """,
            on: database
        ) {
            try await database.schema(Mailbox.schema)
                .field("office_id", .int32, .references(MailboxOffice.schema, "id"))
                .update()
        }

        try await addColumnIfNeeded(
            sql: """
                ALTER TABLE "mailboxes"
                ADD COLUMN IF NOT EXISTS "assigned_person_id" INT
                REFERENCES "persons" ("id")
                ON DELETE NO ACTION
                ON UPDATE NO ACTION
                """,
            on: database
        ) {
            try await database.schema(Mailbox.schema)
                .field("assigned_person_id", .int32, .references(Person.schema, "id"))
                .update()
        }

        try await addColumnIfNeeded(
            sql: """
                ALTER TABLE "mailboxes"
                ADD COLUMN IF NOT EXISTS "assigned_entity_id" INT
                REFERENCES "entities" ("id")
                ON DELETE NO ACTION
                ON UPDATE NO ACTION
                """,
            on: database
        ) {
            try await database.schema(Mailbox.schema)
                .field("assigned_entity_id", .int32, .references(Entity.schema, "id"))
                .update()
        }

        try await addColumnIfNeeded(
            sql: """
                ALTER TABLE "mailboxes"
                ADD COLUMN IF NOT EXISTS "forwarding_email" TEXT
                """,
            on: database
        ) {
            try await database.schema(Mailbox.schema)
                .field("forwarding_email", .string)
                .update()
        }

        try await addColumnIfNeeded(
            sql: """
                ALTER TABLE "mailboxes"
                ADD COLUMN IF NOT EXISTS "activated_at" TIMESTAMPTZ
                """,
            on: database
        ) {
            try await database.schema(Mailbox.schema)
                .field("activated_at", .datetime)
                .update()
        }

        try await addColumnIfNeeded(
            sql: """
                ALTER TABLE "mailboxes"
                ADD COLUMN IF NOT EXISTS "deactivated_at" TIMESTAMPTZ
                """,
            on: database
        ) {
            try await database.schema(Mailbox.schema)
                .field("deactivated_at", .datetime)
                .update()
        }

        try await updateExistingMailboxes(on: database)
    }

    func revert(on database: Database) async throws {
        // SQLite doesn't support dropping multiple columns in one ALTER TABLE
        // Drop each field separately, in reverse order (last added first)
        try await deletingColumnIfPresent(on: database) {
            try await database.schema(Mailbox.schema)
                .deleteField("deactivated_at")
                .update()
        }

        try await deletingColumnIfPresent(on: database) {
            try await database.schema(Mailbox.schema)
                .deleteField("activated_at")
                .update()
        }

        try await deletingColumnIfPresent(on: database) {
            try await database.schema(Mailbox.schema)
                .deleteField("forwarding_email")
                .update()
        }

        try await deletingColumnIfPresent(on: database) {
            try await database.schema(Mailbox.schema)
                .deleteField("assigned_entity_id")
                .update()
        }

        try await deletingColumnIfPresent(on: database) {
            try await database.schema(Mailbox.schema)
                .deleteField("assigned_person_id")
                .update()
        }

        try await deletingColumnIfPresent(on: database) {
            try await database.schema(Mailbox.schema)
                .deleteField("office_id")
                .update()
        }
    }

    private func deletingColumnIfPresent(
        on database: Database,
        _ action: @escaping () async throws -> Void
    ) async throws {
        do {
            try await action()
        } catch {
            if isMissingColumnError(error) {
                return
            }
            throw error
        }
    }

    private func addColumnIfNeeded(
        sql: SQLQueryString,
        on database: Database,
        _ fallback: @escaping () async throws -> Void
    ) async throws {
        if isSQLite(database) {
            // SQLite builds often use a version without "ADD COLUMN IF NOT EXISTS"; prefer schema builder there
            do {
                try await fallback()
            } catch {
                if isDuplicateColumnError(error) {
                    return
                }
                throw error
            }
            return
        }

        if let sqlDatabase = database as? SQLDatabase {
            try await sqlDatabase.raw(sql).run()
            return
        }

        try await fallback()
    }

    private func isMissingColumnError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("no such column") || message.contains("does not exist")
    }

    private func isDuplicateColumnError(_ error: Error) -> Bool {
        let message = String(describing: error).lowercased()
        return message.contains("duplicate column") || message.contains("already exists")
    }

    private func isSQLite(_ database: Database) -> Bool {
        #if canImport(SQLiteKit)
        if database is SQLiteDatabase {
            return true
        }
        #endif

        if let sqlDatabase = database as? SQLDatabase {
            return sqlDatabase.dialect.name.lowercased().contains("sqlite")
        }

        return false
    }

    private func updateExistingMailboxes(on database: Database) async throws {
        guard let sqlDatabase = database as? SQLDatabase else { return }

        try await sqlDatabase.raw(
            """
            UPDATE "mailboxes"
            SET "office_id" = COALESCE("office_id", 1)
            WHERE "office_id" IS NULL
            """
        ).run()

        try await sqlDatabase.raw(
            """
            UPDATE "mailboxes"
            SET "activated_at" = COALESCE("activated_at", "inserted_at", CURRENT_TIMESTAMP)
            WHERE "is_active" = TRUE AND "activated_at" IS NULL
            """
        ).run()
    }
}
