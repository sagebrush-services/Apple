import Fluent
import FluentPostgresDriver
import FluentSQLiteDriver
import Foundation
import Logging
import NotationEngine
import Vapor
import Yams

/// Configures database based on environment - PostgreSQL if POSTGRES_URL exists, SQLite otherwise
public struct DaliConfiguration {
    public static func configureVapor(_ app: Application) async throws {
        // Set log level to error for testing to reduce noise
        if app.environment == .testing {
            app.logger.logLevel = .error
        }

        let envFromVariable = Environment.get("ENV")?.lowercased()
        let isProduction = envFromVariable == "production" || app.environment == .production

        if isProduction {
            // Use PostgreSQL for production
            guard let postgresURL = Environment.get("DATABASE_URL") else {
                throw Abort(.internalServerError, reason: "DATABASE_URL is not configured for production.")
            }
            try app.databases.use(.postgres(url: postgresURL), as: .psql)
        } else if app.environment == .testing {
            // Use in-memory SQLite for tests to keep them isolated and fast
            app.databases.use(.sqlite(.memory), as: .sqlite)
        } else {
            // Use file-backed SQLite for development so data persists across requests
            let sqliteDirectory = app.directory.workingDirectory + "data"
            try FileManager.default.createDirectory(
                atPath: sqliteDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let sqlitePath = sqliteDirectory + "/bazaar-development.sqlite"
            app.logger.info("Using SQLite database at \(sqlitePath)")
            app.databases.use(.sqlite(.file(sqlitePath)), as: .sqlite)
        }

        // Add migrations in timestamp order
        for migration in migrations {
            app.migrations.add(migration)
        }

        // Run migrations
        try await app.autoMigrate()

        // Run seeds
        try await runSeeds(on: app.db, environment: app.environment)
    }

    /// Array of migrations in timestamp order
    private static let migrations: [Migration] = [
        CreatePeople(),
        CreateUsers(),
        CreateJurisdictions(),
        CreateEntityTypes(),
        CreateEntities(),
        CreateShareClasses(),
        CreateBlobs(),
        CreateProjects(),
        CreateCredentials(),
        CreateRelationshipLogs(),
        CreateDisclosures(),
        CreateQuestions(),
        CreateAddresses(),
        CreateMailboxOffices(),
        CreateMailboxes(),
        CreatePersonEntityRoles(),
        CreateFlowInstances(),
        CreateFlowSteps(),
        UpdateMailboxesForOffices(),
        CreateMailItems(),
        EnhanceFormationTracking(),
    ]

    private static let seedOrder: [String] = [
        "Jurisdiction",
        "EntityType",
        "Question",
        "Person",
        "User",
        "Entity",
        "Credential",
        "Address",
        "MailboxOffice",
        "Mailbox",
        "PersonEntityRole",
    ]

    /// Run seeds from YAML files based on model names
    private static func runSeeds(on database: Database, environment: Environment) async throws {
        var logger = Logger(label: "dali-seeds")
        // Set log level to error for testing to reduce noise
        if environment == .testing {
            logger.logLevel = .error
        }
        logger.info("Starting seed process")

        for modelName in seedOrder {
            logger.info("Processing seeds for model: \(modelName)")

            // Look for seed files that match this model
            let seedFiles = findSeedFiles(for: modelName, environment: environment)

            for seedFile in seedFiles {
                logger.info("Loading seed file: \(seedFile)")

                try await processSeedFile(
                    seedFile,
                    modelName: modelName,
                    database: database,
                    logger: logger
                )
            }
        }

        logger.info("Seed process completed")
    }

    /// Find seed files that match a given model name
    private static func findSeedFiles(for modelName: String, environment: Environment) -> [String] {
        // Look for files with simple naming pattern: ModelName.yaml
        var logger = Logger(label: "dali-seeds-finder")
        // Set log level to error for testing to reduce noise
        if environment == .testing {
            logger.logLevel = .error
        }

        // Try Bundle.module first
        if let seedURL = Bundle.module.url(forResource: "Seeds/\(modelName)", withExtension: "yaml") {
            if FileManager.default.fileExists(atPath: seedURL.path) {
                logger.info("Found seed file via Bundle.module: \(seedURL.path)")
                return [modelName]  // Return just the model name without .yaml extension
            }
        }

        // Fallback: try to find the file relative to the current working directory
        let fallbackPath = "Sources/Dali/Seeds/\(modelName).yaml"
        if FileManager.default.fileExists(atPath: fallbackPath) {
            logger.info("Found seed file via fallback path: \(fallbackPath)")
            return [modelName]
        }

        logger.warning("No seed file found for model: \(modelName)")
        return []
    }

    /// Process a seed file dynamically based on the model name
    private static func processSeedFile(
        _ seedFile: String,
        modelName: String,
        database: Database,
        logger: Logger
    ) async throws {
        var seedURL: URL?

        // Try Bundle.module first
        if let bundleURL = Bundle.module.url(forResource: "Seeds/\(seedFile)", withExtension: "yaml") {
            if FileManager.default.fileExists(atPath: bundleURL.path) {
                seedURL = bundleURL
            }
        }

        // Fallback: try relative path
        if seedURL == nil {
            let fallbackPath = "Sources/Dali/Seeds/\(seedFile).yaml"
            if FileManager.default.fileExists(atPath: fallbackPath) {
                seedURL = URL(fileURLWithPath: fallbackPath)
            }
        }

        guard let finalURL = seedURL else {
            logger.warning("Seed file not found: Seeds/\(seedFile).yaml")
            return
        }

        logger.info("Processing seed file: \(finalURL.path)")

        // Read and parse YAML file
        let yamlData = try Data(contentsOf: finalURL)
        let seedData = try parseYAML(from: yamlData)

        logger.info("Found \(seedData.records.count) \(modelName) records with lookup fields: \(seedData.lookupFields)")

        // Process each record
        for (index, record) in seedData.records.enumerated() {
            do {
                try await insertRecord(
                    record: record,
                    modelName: modelName,
                    lookupFields: seedData.lookupFields,
                    database: database,
                    logger: logger
                )
                logger.debug("✓ Inserted \(modelName) record \(index + 1)/\(seedData.records.count)")
            } catch {
                logger.error("✗ Failed to insert \(modelName) record \(index + 1): \(error)")
            }
        }

        logger.info("Completed processing \(seedData.records.count) \(modelName) records")
    }

    /// Insert or update a record using native Fluent
    private static func insertRecord(
        record: [String: Any],
        modelName: String,
        lookupFields: [String],
        database: Database,
        logger: Logger
    ) async throws {
        switch modelName {
        case "Jurisdiction":
            try await insertJurisdiction(record: record, lookupFields: lookupFields, database: database)
        case "EntityType":
            try await insertEntityType(record: record, lookupFields: lookupFields, database: database)
        case "Question":
            try await insertQuestion(record: record, lookupFields: lookupFields, database: database)
        case "Person":
            try await insertPerson(record: record, lookupFields: lookupFields, database: database)
        case "User":
            try await insertUser(record: record, lookupFields: lookupFields, database: database)
        case "Entity":
            try await insertEntity(record: record, lookupFields: lookupFields, database: database)
        case "Credential":
            try await insertCredential(record: record, lookupFields: lookupFields, database: database)
        case "Address":
            try await insertAddress(record: record, lookupFields: lookupFields, database: database)
        case "MailboxOffice":
            try await insertMailboxOffice(record: record, lookupFields: lookupFields, database: database)
        case "Mailbox":
            try await insertMailbox(record: record, lookupFields: lookupFields, database: database)
        case "PersonEntityRole":
            try await insertPersonEntityRole(record: record, lookupFields: lookupFields, database: database)
        default:
            logger.warning("Unknown model type: \(modelName)")
        }
    }

    // MARK: - Helper functions

    private static func resolveForeignKey(
        _ key: String,
        from record: [String: Any],
        database: Database
    ) async throws -> Int32? {
        let directIdKey = "\(key)_id"

        if let directId = record[directIdKey] as? Int32 {
            return directId
        }
        if let directIdString = record[directIdKey] as? String, let directId = Int32(directIdString) {
            return directId
        }

        if let nestedData = record[key] as? [String: Any] {
            switch key {
            case "entity":
                return try await findOrCreateEntity(from: nestedData, database: database)
            case "person":
                if let email = nestedData["email"] as? String {
                    let person = try await Person.query(on: database)
                        .filter(\.$email == email)
                        .first()
                    return person?.id
                }
            case "jurisdiction":
                if let name = nestedData["name"] as? String {
                    let jurisdiction = try await Jurisdiction.query(on: database)
                        .filter(\.$name == name)
                        .first()
                    return jurisdiction?.id
                }
            case "address":
                return try await findOrCreateAddress(from: nestedData, database: database)
            case "office":
                return try await findOrCreateMailboxOffice(from: nestedData, database: database)
            default:
                break
            }
        }

        return nil
    }

    private static func findOrCreateEntity(
        from entityData: [String: Any],
        database: Database
    ) async throws -> Int32? {
        let name = entityData["name"] as? String ?? ""

        if let existing = try await Entity.query(on: database)
            .filter(\.$name == name)
            .first()
        {
            return existing.id
        }

        let entity = Entity()
        entity.name = name

        if let entityTypeData = entityData["entity_type"] as? [String: Any],
            let entityTypeName = entityTypeData["name"] as? String
        {

            if let jurisdictionData = entityTypeData["jurisdiction"] as? [String: Any],
                let jurisdictionName = jurisdictionData["name"] as? String
            {

                let jurisdiction = try await Jurisdiction.query(on: database)
                    .filter(\.$name == jurisdictionName)
                    .first()

                if let jurisdictionId = jurisdiction?.id {
                    let entityType = try await EntityType.query(on: database)
                        .filter(\.$name == entityTypeName)
                        .filter(\.$jurisdiction.$id == jurisdictionId)
                        .first()

                    if let entityTypeId = entityType?.id {
                        entity.$legalEntityType.id = entityTypeId
                    }
                }
            }
        }

        try await entity.save(on: database)
        return entity.id
    }

    private static func findOrCreateAddress(
        from addressData: [String: Any],
        database: Database
    ) async throws -> Int32? {
        let zip = addressData["zip"] as? String ?? ""
        let street = addressData["street"] as? String ?? ""

        if let existing = try await Address.query(on: database)
            .filter(\.$zip == zip)
            .filter(\.$street == street)
            .first()
        {
            return existing.id
        }

        let address = Address()
        address.street = street
        address.city = addressData["city"] as? String ?? ""
        address.state = addressData["state"] as? String ?? ""
        address.zip = zip
        address.country = addressData["country"] as? String ?? "USA"
        address.isVerified = addressData["is_verified"] as? Bool ?? false

        if let entityId = try await resolveForeignKey("entity", from: addressData, database: database) {
            address.$entity.id = entityId
        }

        try await address.save(on: database)
        return address.id
    }

    // MARK: - Model-specific insert functions

    private static func insertJurisdiction(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let name = record["name"] as? String ?? ""
        let code = record["code"] as? String ?? ""

        if !lookupFields.isEmpty {
            var query = Jurisdiction.query(on: database)

            if lookupFields.contains("name") && !name.isEmpty {
                query = query.filter(\.$name == name)
            }

            if lookupFields.contains("code") && !code.isEmpty {
                query = query.filter(\.$code == code)
            }

            if let existing = try await query.first() {
                existing.name = name.isEmpty ? existing.name : name
                existing.code = code.isEmpty ? existing.code : code
                if let jurisdictionTypeString = record["jurisdiction_type"] as? String,
                    let jurisdictionType = JurisdictionType(rawValue: jurisdictionTypeString)
                {
                    existing.jurisdictionType = jurisdictionType
                }
                try await existing.save(on: database)
                return
            }
        }

        let jurisdiction = Jurisdiction()
        jurisdiction.code = code
        jurisdiction.name = name
        if let jurisdictionTypeString = record["jurisdiction_type"] as? String,
            let jurisdictionType = JurisdictionType(rawValue: jurisdictionTypeString)
        {
            jurisdiction.jurisdictionType = jurisdictionType
        } else {
            // Default to state for US jurisdictions based on 2-letter codes
            jurisdiction.jurisdictionType = .state
        }
        try await jurisdiction.save(on: database)
    }

    private static func insertEntityType(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let name = record["name"] as? String ?? ""

        // Look up jurisdiction by nested reference or direct ID
        let jurisdictionId: Int32?
        if let jurisdictionDict = record["jurisdiction"] as? [String: Any],
            let jurisdictionName = jurisdictionDict["name"] as? String
        {
            // Handle nested jurisdiction reference
            let jurisdiction = try await Jurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
            jurisdictionId = jurisdiction?.id
        } else if let jurisdictionIdString = record["jurisdiction_id"] as? String {
            // Handle direct UUID reference
            jurisdictionId = Int32(jurisdictionIdString)
        } else {
            jurisdictionId = nil
        }

        // Check for existing record using lookupFields
        if !lookupFields.isEmpty,
            let jurisdictionId = jurisdictionId
        {
            if let existing = try await EntityType.query(on: database)
                .filter(\.$name == name)
                .filter(\.$jurisdiction.$id == jurisdictionId)
                .first()
            {
                // Record exists, no updates needed since EntityType doesn't have updatable fields
                try await existing.save(on: database)
                return
            }
        }

        let entityType = EntityType()
        entityType.name = name
        if let jurisdictionId = jurisdictionId {
            entityType.$jurisdiction.id = jurisdictionId
        }
        try await entityType.save(on: database)
    }

    private static func insertQuestion(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        if !lookupFields.isEmpty, let code = record["code"] as? String {
            if let existing = try await Question.query(on: database)
                .filter(\.$code == code)
                .first()
            {
                existing.prompt = record["prompt"] as? String ?? existing.prompt
                if let questionTypeString = record["question_type"] as? String,
                    let questionType = QuestionType(rawValue: questionTypeString)
                {
                    existing.questionType = questionType
                }
                existing.helpText = record["help_text"] as? String ?? existing.helpText
                existing.choices = record["choices"] as? [String: String] ?? existing.choices
                try await existing.save(on: database)
                return
            }
        }

        let question = Question()
        question.prompt = record["prompt"] as? String ?? ""
        if let questionTypeString = record["question_type"] as? String,
            let questionType = QuestionType(rawValue: questionTypeString)
        {
            question.questionType = questionType
        } else {
            question.questionType = .string  // Default value
        }
        question.code = record["code"] as? String ?? ""
        question.helpText = record["help_text"] as? String ?? ""
        question.choices = record["choices"] as? [String: String]
        try await question.save(on: database)
    }

    private static func insertPerson(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        if !lookupFields.isEmpty, let email = record["email"] as? String {
            if let existing = try await Person.query(on: database)
                .filter(\.$email == email)
                .first()
            {
                existing.name = record["name"] as? String ?? existing.name
                try await existing.save(on: database)
                return
            }
        }

        let person = Person()
        person.name = record["name"] as? String ?? ""
        person.email = record["email"] as? String ?? ""
        try await person.save(on: database)
    }

    private static func insertUser(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Look up Person by nested reference
        let personId: Int32?
        if let personDict = record["person"] as? [String: Any],
            let personEmail = personDict["email"] as? String
        {
            let person = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()
            personId = person?.id
        } else {
            personId = nil
        }

        guard let personId = personId else {
            return
        }

        // Check for existing user using lookupFields
        if !lookupFields.isEmpty {
            if let existing = try await User.query(on: database)
                .filter(\.$person.$id == personId)
                .first()
            {
                // Update role if provided
                if let roleString = record["role"] as? String,
                    let role = UserRole(rawValue: roleString)
                {
                    existing.role = role
                }
                try await existing.save(on: database)
                return
            }
        }

        let user = User()
        user.$person.id = personId
        if let roleString = record["role"] as? String,
            let role = UserRole(rawValue: roleString)
        {
            user.role = role
        } else {
            user.role = .customer  // Default to customer
        }
        try await user.save(on: database)
    }

    private static func insertEntity(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let name = record["name"] as? String ?? ""

        // Look up EntityType by nested reference or direct ID
        let entityTypeId: Int32?
        if let entityTypeDict = record["entity_type"] as? [String: Any],
            let entityTypeName = entityTypeDict["name"] as? String
        {
            // Handle nested legal entity type reference with jurisdiction lookup
            if let jurisdictionDict = entityTypeDict["jurisdiction"] as? [String: Any],
                let jurisdictionName = jurisdictionDict["name"] as? String
            {
                // First find the jurisdiction
                let jurisdiction = try await Jurisdiction.query(on: database)
                    .filter(\.$name == jurisdictionName)
                    .first()

                if let jurisdictionId = jurisdiction?.id {
                    // Then find the EntityType
                    let entityType = try await EntityType.query(on: database)
                        .filter(\.$name == entityTypeName)
                        .filter(\.$jurisdiction.$id == jurisdictionId)
                        .first()
                    entityTypeId = entityType?.id
                } else {
                    entityTypeId = nil
                }
            } else {
                // Look up by name only (less reliable)
                let entityType = try await EntityType.query(on: database)
                    .filter(\.$name == entityTypeName)
                    .first()
                entityTypeId = entityType?.id
            }
        } else if let entityTypeIdString = record["legal_entity_type_id"] as? String {
            // Handle direct UUID reference
            entityTypeId = Int32(entityTypeIdString)
        } else {
            entityTypeId = nil
        }

        // Check for existing record using lookupFields
        if !lookupFields.isEmpty, !name.isEmpty {
            if let existing = try await Entity.query(on: database)
                .filter(\.$name == name)
                .first()
            {
                // Update the legal entity type if provided
                if let entityTypeId = entityTypeId {
                    existing.$legalEntityType.id = entityTypeId
                }
                try await existing.save(on: database)
                return
            }
        }

        let entity = Entity()
        entity.name = name
        if let entityTypeId = entityTypeId {
            entity.$legalEntityType.id = entityTypeId
        }
        try await entity.save(on: database)
    }

    private static func insertCredential(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let licenseNumber = record["license_number"] as? String ?? ""

        // Look up Person by nested reference or direct ID
        let personId: Int32?
        if let personDict = record["person"] as? [String: Any],
            let personEmail = personDict["email"] as? String
        {
            // Handle nested person reference
            let person = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()
            personId = person?.id
        } else if let personIdString = record["person_id"] as? String {
            // Handle direct UUID reference
            personId = Int32(personIdString)
        } else {
            personId = nil
        }

        // Look up Jurisdiction by nested reference or direct ID
        let jurisdictionId: Int32?
        if let jurisdictionDict = record["jurisdiction"] as? [String: Any],
            let jurisdictionName = jurisdictionDict["name"] as? String
        {
            // Handle nested jurisdiction reference
            let jurisdiction = try await Jurisdiction.query(on: database)
                .filter(\.$name == jurisdictionName)
                .first()
            jurisdictionId = jurisdiction?.id
        } else if let jurisdictionIdString = record["jurisdiction_id"] as? String {
            // Handle direct UUID reference
            jurisdictionId = Int32(jurisdictionIdString)
        } else {
            jurisdictionId = nil
        }

        // Check for existing record using lookupFields
        if !lookupFields.isEmpty, !licenseNumber.isEmpty {
            if let existing = try await Credential.query(on: database)
                .filter(\.$licenseNumber == licenseNumber)
                .first()
            {
                // Update references if provided
                if let personId = personId {
                    existing.$person.id = personId
                }
                if let jurisdictionId = jurisdictionId {
                    existing.$jurisdiction.id = jurisdictionId
                }
                try await existing.save(on: database)
                return
            }
        }

        let credential = Credential()
        credential.licenseNumber = licenseNumber
        if let personId = personId {
            credential.$person.id = personId
        }
        if let jurisdictionId = jurisdictionId {
            credential.$jurisdiction.id = jurisdictionId
        }
        try await credential.save(on: database)
    }

    private static func insertAddress(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let zip = record["zip"] as? String ?? ""
        let street = record["street"] as? String ?? ""

        if !lookupFields.isEmpty {
            var query = Address.query(on: database)

            if lookupFields.contains("zip") && !zip.isEmpty {
                query = query.filter(\.$zip == zip)
            }

            if lookupFields.contains("entity_id"),
                let entityId = try await resolveForeignKey("entity", from: record, database: database)
            {
                query = query.filter(\.$entity.$id == entityId)
            }

            if let existing = try await query.first() {
                if let entityId = try await resolveForeignKey("entity", from: record, database: database) {
                    existing.$entity.id = entityId
                }
                try await existing.save(on: database)
                return
            }
        }

        let address = Address()
        address.street = street
        address.city = record["city"] as? String ?? ""
        address.state = record["state"] as? String ?? ""
        address.zip = zip
        address.country = record["country"] as? String ?? "USA"
        address.isVerified = record["is_verified"] as? Bool ?? false

        if let entityId = try await resolveForeignKey("entity", from: record, database: database) {
            address.$entity.id = entityId
        }

        try await address.save(on: database)
    }

    private static func findOrCreateMailboxOffice(
        from officeData: [String: Any],
        database: Database
    ) async throws -> Int32? {
        guard let name = officeData["name"] as? String, !name.isEmpty else {
            return nil
        }

        if let existing = try await MailboxOffice.query(on: database)
            .filter(\.$name == name)
            .first()
        {
            return existing.id
        }

        let office = MailboxOffice()
        office.name = name
        office.addressLine1 = officeData["address_line1"] as? String ?? ""
        office.addressLine2 = officeData["address_line2"] as? String
        office.city = officeData["city"] as? String ?? ""
        office.state = officeData["state"] as? String ?? ""
        office.postalCode = officeData["postal_code"] as? String ?? ""
        office.country = officeData["country"] as? String ?? "USA"
        office.mailboxStart = officeData["mailbox_start"] as? Int ?? 9000
        office.mailboxEnd = officeData["mailbox_end"] as? Int ?? 9999
        office.capacity = officeData["capacity"] as? Int

        try await office.save(on: database)
        return office.id
    }

    private static func insertMailboxOffice(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let name = record["name"] as? String ?? ""

        if !lookupFields.isEmpty, lookupFields.contains("name"), !name.isEmpty {
            if let _ = try await MailboxOffice.query(on: database)
                .filter(\.$name == name)
                .first()
            {
                return
            }
        }

        let office = MailboxOffice()
        office.name = name
        office.addressLine1 = record["address_line1"] as? String ?? ""
        office.addressLine2 = record["address_line2"] as? String
        office.city = record["city"] as? String ?? ""
        office.state = record["state"] as? String ?? ""
        office.postalCode = record["postal_code"] as? String ?? ""
        office.country = record["country"] as? String ?? "USA"
        office.mailboxStart = record["mailbox_start"] as? Int ?? 9000
        office.mailboxEnd = record["mailbox_end"] as? Int ?? 9999
        office.capacity = record["capacity"] as? Int

        try await office.save(on: database)
    }

    private static func insertMailbox(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        let mailboxNumber = record["mailbox_number"] as? Int ?? 0

        if !lookupFields.isEmpty {
            var query = Mailbox.query(on: database)

            if lookupFields.contains("mailbox_number") && mailboxNumber > 0 {
                query = query.filter(\.$mailboxNumber == mailboxNumber)
            }

            if lookupFields.contains("address_id"),
                let addressId = try await resolveForeignKey("address", from: record, database: database)
            {
                query = query.filter(\.$address.$id == addressId)
            }

            if let existing = try await query.first() {
                if let addressId = try await resolveForeignKey("address", from: record, database: database) {
                    existing.$address.id = addressId
                }
                if let officeId = try await resolveForeignKey("office", from: record, database: database) {
                    existing.$office.id = officeId
                }
                existing.isActive = record["is_active"] as? Bool ?? existing.isActive
                try await existing.save(on: database)
                return
            }
        }

        let mailbox = Mailbox()
        mailbox.mailboxNumber = mailboxNumber
        mailbox.isActive = record["is_active"] as? Bool ?? true

        if let addressId = try await resolveForeignKey("address", from: record, database: database) {
            mailbox.$address.id = addressId
        }

        if let officeId = try await resolveForeignKey("office", from: record, database: database) {
            mailbox.$office.id = officeId
        } else {
            mailbox.$office.id = 1
        }

        try await mailbox.save(on: database)
    }

    private static func insertPersonEntityRole(
        record: [String: Any],
        lookupFields: [String],
        database: Database
    ) async throws {
        // Look up Person by nested reference
        let personId: Int32?
        if let personDict = record["person"] as? [String: Any],
            let personEmail = personDict["email"] as? String
        {
            let person = try await Person.query(on: database)
                .filter(\.$email == personEmail)
                .first()
            personId = person?.id
        } else if let personIdString = record["person_id"] as? String {
            personId = Int32(personIdString)
        } else {
            personId = nil
        }

        // Look up Entity by nested reference
        let entityId: Int32?
        if let entityDict = record["entity"] as? [String: Any],
            let entityName = entityDict["name"] as? String
        {
            let entity = try await Entity.query(on: database)
                .filter(\.$name == entityName)
                .first()
            entityId = entity?.id
        } else if let entityIdString = record["entity_id"] as? String {
            entityId = Int32(entityIdString)
        } else {
            entityId = nil
        }

        let role = record["role"] as? String ?? "admin"

        // Check for existing record using lookupFields
        if !lookupFields.isEmpty,
            let personId = personId,
            let entityId = entityId
        {
            let existing = try await PersonEntityRole.query(on: database)
                .filter(\.$person.$id == personId)
                .filter(\.$entity.$id == entityId)
                .filter(\.$role == PersonEntityRoleType(rawValue: role)!)
                .first()

            if existing != nil {
                // Record already exists, no need to update
                return
            }
        }

        let personEntityRole = PersonEntityRole()
        if let personId = personId {
            personEntityRole.$person.id = personId
        }
        if let entityId = entityId {
            personEntityRole.$entity.id = entityId
        }
        if let roleType = PersonEntityRoleType(rawValue: role) {
            personEntityRole.role = roleType
        }
        try await personEntityRole.save(on: database)
    }

    /// Parse YAML data into seed structure
    private static func parseYAML(from data: Data) throws -> SeedData {
        let yaml = try Yams.load(yaml: String(data: data, encoding: .utf8)!)

        guard let yamlDict = yaml as? [String: Any] else {
            throw SeedError.invalidYAMLStructure
        }

        let lookupFields = yamlDict["lookup_fields"] as? [String] ?? []
        let records = yamlDict["records"] as? [[String: Any]] ?? []

        return SeedData(lookupFields: lookupFields, records: records)
    }
}

// MARK: - Supporting Types

struct SeedData {
    let lookupFields: [String]
    let records: [[String: Any]]
}

enum SeedError: Error {
    case invalidYAMLStructure
    case missingRequiredField(String)
    case unsupportedModel(String)
}
