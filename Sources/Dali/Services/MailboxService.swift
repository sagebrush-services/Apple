import Fluent
import Foundation
import Vapor

public actor MailboxService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    // MARK: - Offices

    public func listOffices() async throws -> [MailboxOffice] {
        try await MailboxOffice.query(on: database)
            .sort(\.$name, .ascending)
            .all()
    }

    public func getOffice(id: Int32) async throws -> MailboxOffice {
        guard let office = try await MailboxOffice.find(id, on: database) else {
            throw Abort(.notFound, reason: "Mailbox office not found")
        }
        return office
    }

    public func createOffice(
        name: String,
        addressLine1: String,
        addressLine2: String?,
        city: String,
        state: String,
        postalCode: String,
        country: String,
        mailboxStart: Int,
        mailboxEnd: Int,
        capacity: Int?
    ) async throws -> MailboxOffice {
        let office = MailboxOffice(
            name: name,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            state: state,
            postalCode: postalCode,
            country: country,
            mailboxStart: mailboxStart,
            mailboxEnd: mailboxEnd,
            capacity: capacity
        )
        try await office.save(on: database)
        return office
    }

    public func updateOffice(
        id: Int32,
        name: String,
        addressLine1: String,
        addressLine2: String?,
        city: String,
        state: String,
        postalCode: String,
        country: String,
        mailboxStart: Int,
        mailboxEnd: Int,
        capacity: Int?
    ) async throws -> MailboxOffice {
        let office = try await getOffice(id: id)
        office.name = name
        office.addressLine1 = addressLine1
        office.addressLine2 = addressLine2
        office.city = city
        office.state = state
        office.postalCode = postalCode
        office.country = country
        office.mailboxStart = mailboxStart
        office.mailboxEnd = mailboxEnd
        office.capacity = capacity
        try await office.save(on: database)
        return office
    }

    // MARK: - Mailboxes

    public struct MailboxFilter: Sendable {
        public var officeID: Int32?
        public var activeOnly: Bool?

        public init(officeID: Int32? = nil, activeOnly: Bool? = nil) {
            self.officeID = officeID
            self.activeOnly = activeOnly
        }
    }

    public func listMailboxes(filter: MailboxFilter = .init()) async throws -> [Mailbox] {
        var query = Mailbox.query(on: database)
            .with(\.$office)
            .with(\.$address)
            .with(\.$assignedPerson)
            .with(\.$assignedEntity)

        if let officeID = filter.officeID {
            query = query.filter(\.$office.$id == officeID)
        }

        if let activeOnly = filter.activeOnly {
            query = query.filter(\.$isActive == activeOnly)
        }

        return try await query
            .sort(\.$mailboxNumber, .ascending)
            .all()
    }

    public func mailboxes(for user: User) async throws -> [Mailbox] {
        let personID = try user.person.requireID()
        return try await Mailbox.query(on: database)
            .with(\.$office)
            .filter(\.$assignedPerson.$id == personID)
            .sort(\.$mailboxNumber, .ascending)
            .all()
    }

    /// Returns the mailbox currently assigned to the provided entity, if any.
    public func mailbox(forEntityID entityID: Int32) async throws -> Mailbox? {
        try await Mailbox.query(on: database)
            .with(\.$office)
            .with(\.$address)
            .filter(\.$assignedEntity.$id == entityID)
            .first()
    }

    /// Ensures the given entity has an active mailbox. If one already exists, it is returned
    /// after applying any updated forwarding preferences. Otherwise the next available mailbox
    /// in the specified office is provisioned and returned.
    public func ensureMailboxForEntity(
        entityID: Int32,
        officeID: Int32,
        forwardingEmail: String? = nil,
        activatedAt: Date = Date()
    ) async throws -> Mailbox {
        if let existing = try await mailbox(forEntityID: entityID) {
            let normalizedEmail = normalize(email: forwardingEmail)
            var shouldSave = false

            if existing.forwardingEmail != normalizedEmail {
                existing.forwardingEmail = normalizedEmail
                shouldSave = true
            }
            if !existing.isActive {
                existing.isActive = true
                existing.deactivatedAt = nil
                if existing.activatedAt == nil {
                    existing.activatedAt = activatedAt
                }
                shouldSave = true
            }
            if shouldSave {
                try await existing.save(on: database)
            }
            return existing
        }

        guard let office = try await MailboxOffice.find(officeID, on: database) else {
            throw Abort(.notFound, reason: "Mailbox office not found")
        }

        // Determine the next available mailbox number within the office range.
        let highestNumber = try await Mailbox.query(on: database)
            .filter(\.$office.$id == officeID)
            .sort(\.$mailboxNumber, .descending)
            .first()
            .map(\.mailboxNumber)

        let nextNumber: Int
        if let highestNumber {
            nextNumber = highestNumber + 1
        } else {
            nextNumber = office.mailboxStart
        }

        guard nextNumber <= office.mailboxEnd else {
            throw Abort(.conflict, reason: "No available mailboxes remaining for \(office.name).")
        }

        // Create a mailing address for the entity that reflects the assigned mailbox number.
        let address = Address()
        address.$entity.id = entityID
        address.street = "\(office.addressLine1) Mailbox \(nextNumber)"
        address.city = office.city
        address.state = office.state
        address.zip = office.postalCode
        address.country = office.country
        address.isVerified = true
        try await address.save(on: database)

        let mailbox = Mailbox()
        mailbox.$address.id = try address.requireID()
        mailbox.$office.id = try office.requireID()
        mailbox.mailboxNumber = nextNumber
        mailbox.isActive = true
        mailbox.$assignedEntity.id = entityID
        mailbox.$assignedPerson.id = nil
        mailbox.forwardingEmail = normalize(email: forwardingEmail)
        mailbox.activatedAt = activatedAt
        mailbox.deactivatedAt = nil
        try await mailbox.save(on: database)

        return mailbox
    }

    public func assignMailbox(
        mailboxID: Int32,
        personID: Int32?,
        entityID: Int32?,
        forwardingEmail: String?,
        activatedAt: Date = Date()
    ) async throws -> Mailbox {
        guard let mailbox = try await Mailbox.find(mailboxID, on: database) else {
            throw Abort(.notFound, reason: "Mailbox not found")
        }

        if let personID {
            mailbox.$assignedPerson.id = personID
        } else {
            mailbox.$assignedPerson.id = nil
        }

        if let entityID {
            mailbox.$assignedEntity.id = entityID
        } else {
            mailbox.$assignedEntity.id = nil
        }

        mailbox.forwardingEmail = forwardingEmail
        mailbox.isActive = true
        mailbox.activatedAt = activatedAt
        mailbox.deactivatedAt = nil

        try await mailbox.save(on: database)
        return mailbox
    }

    public func releaseMailbox(mailboxID: Int32, deactivatedAt: Date = Date()) async throws -> Mailbox {
        guard let mailbox = try await Mailbox.find(mailboxID, on: database) else {
            throw Abort(.notFound, reason: "Mailbox not found")
        }

        mailbox.$assignedPerson.id = nil
        mailbox.$assignedEntity.id = nil
        mailbox.forwardingEmail = nil
        mailbox.isActive = false
        mailbox.deactivatedAt = deactivatedAt

        try await mailbox.save(on: database)
        return mailbox
    }

    public func activateMailbox(mailboxID: Int32, activatedAt: Date = Date(), forwardingEmail: String? = nil) async throws -> Mailbox {
        guard let mailbox = try await Mailbox.find(mailboxID, on: database) else {
            throw Abort(.notFound, reason: "Mailbox not found")
        }

        mailbox.isActive = true
        mailbox.forwardingEmail = forwardingEmail
        mailbox.activatedAt = activatedAt
        mailbox.deactivatedAt = nil

        try await mailbox.save(on: database)
        return mailbox
    }

    /// Allocates the next available mailbox for a formation.
    /// This is used when a formation needs a mailbox before an entity is created.
    /// The mailbox will be linked to the entity later when the formation is completed.
    public func allocateMailboxForFormation(
        officeID: Int32,
        forwardingEmail: String? = nil,
        activatedAt: Date = Date()
    ) async throws -> Mailbox {
        guard let office = try await MailboxOffice.find(officeID, on: database) else {
            throw Abort(.notFound, reason: "Mailbox office not found")
        }

        // Determine the next available mailbox number within the office range.
        let highestNumber = try await Mailbox.query(on: database)
            .filter(\.$office.$id == officeID)
            .sort(\.$mailboxNumber, .descending)
            .first()
            .map(\.mailboxNumber)

        let nextNumber: Int
        if let highestNumber {
            nextNumber = highestNumber + 1
        } else {
            nextNumber = office.mailboxStart
        }

        guard nextNumber <= office.mailboxEnd else {
            throw Abort(.conflict, reason: "No available mailboxes remaining for \(office.name).")
        }

        // Create a temporary address for the mailbox
        // This will be replaced when the entity is created
        let address = Address()
        address.street = "\(office.addressLine1) Mailbox \(nextNumber)"
        address.city = office.city
        address.state = office.state
        address.zip = office.postalCode
        address.country = office.country
        address.isVerified = true
        try await address.save(on: database)

        let mailbox = Mailbox()
        mailbox.$address.id = try address.requireID()
        mailbox.$office.id = try office.requireID()
        mailbox.mailboxNumber = nextNumber
        mailbox.isActive = true
        mailbox.$assignedEntity.id = nil  // Will be set when entity is created
        mailbox.$assignedPerson.id = nil
        mailbox.forwardingEmail = normalize(email: forwardingEmail)
        mailbox.activatedAt = activatedAt
        mailbox.deactivatedAt = nil
        try await mailbox.save(on: database)

        return mailbox
    }

    /// Links an existing mailbox to an entity.
    /// This is used when a formation is completed and the entity is created.
    public func linkMailboxToEntity(
        mailboxID: Int32,
        entityID: Int32
    ) async throws -> Mailbox {
        guard let mailbox = try await Mailbox.find(mailboxID, on: database) else {
            throw Abort(.notFound, reason: "Mailbox not found")
        }

        // Update the mailbox to point to the entity
        mailbox.$assignedEntity.id = entityID

        // Update the address to be linked to the entity
        let addressID = mailbox.$address.id
        if let address = try await Address.find(addressID, on: database) {
            address.$entity.id = entityID
            try await address.save(on: database)
        }

        try await mailbox.save(on: database)
        return mailbox
    }

    private func normalize(email: String?) -> String? {
        guard let email else { return nil }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
