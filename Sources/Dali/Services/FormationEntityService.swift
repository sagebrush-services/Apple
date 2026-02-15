import Fluent
import Foundation

/// Service for extracting entity information from formation flow steps and creating entities.
public actor FormationEntityService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public enum ExtractionError: Error, LocalizedError {
        case entityNameNotFound
        case invalidEntityType
        case noJurisdictionFound

        public var errorDescription: String? {
            switch self {
            case .entityNameNotFound:
                return "Entity name not found in formation steps"
            case .invalidEntityType:
                return "Invalid or unsupported entity type"
            case .noJurisdictionFound:
                return "No jurisdiction found for entity type"
            }
        }
    }

    /// Extracted entity information from formation steps
    public struct EntityInfo: Sendable {
        public let name: String
        public let entityTypeID: Int32?
        public let jurisdiction: String?

        public init(name: String, entityTypeID: Int32? = nil, jurisdiction: String? = nil) {
            self.name = name
            self.entityTypeID = entityTypeID
            self.jurisdiction = jurisdiction
        }
    }

    /// Extracts entity information from formation flow steps.
    /// This looks for the entity_name question code and optionally other entity details.
    public func extractEntityInfo(fromFormation formation: FlowInstanceRecord) async throws -> EntityInfo {
        // Load all steps for this formation
        let steps = try await FlowStepRecord.query(on: database)
            .filter(\.$instance.$id == formation.requireID())
            .all()

        // Find the entity name step
        guard let nameStep = steps.first(where: { $0.questionCode == "entity_name" }),
            let entityName = nameStep.answerPayload.stringValue,
            !entityName.isEmpty
        else {
            throw ExtractionError.entityNameNotFound
        }

        // For now, we'll default to LLC entity type in Nevada
        // This can be enhanced later to extract from flow steps if needed
        let entityTypeID = try await resolveEntityType(for: "LLC", jurisdiction: "Nevada")

        return EntityInfo(
            name: entityName,
            entityTypeID: entityTypeID,
            jurisdiction: "Nevada"
        )
    }

    /// Creates an Entity record from the extracted information.
    /// This is called when a formation status changes to 'formed'.
    public func createEntity(
        from info: EntityInfo,
        formationID: UUID
    ) async throws -> Entity {
        let entity = Entity()
        entity.name = info.name

        if let entityTypeID = info.entityTypeID {
            entity.$legalEntityType.id = entityTypeID
        }

        try await entity.save(on: database)

        return entity
    }

    /// Creates an entity from a formation and links it back to the formation.
    /// This is the main entry point for entity creation during formation completion.
    public func createEntityFromFormation(
        formation: FlowInstanceRecord
    ) async throws -> Entity {
        // Check if entity already exists
        if let existingEntityID = formation.respondentEntityID,
            let existing = try await Entity.find(existingEntityID, on: database)
        {
            return existing
        }

        // Extract entity info from flow steps
        let info = try await extractEntityInfo(fromFormation: formation)

        // Create the entity
        let entity = try await createEntity(from: info, formationID: formation.requireID())

        // Link entity back to formation
        formation.respondentEntityID = try entity.requireID()
        try await formation.save(on: database)

        return entity
    }

    // MARK: - Private Helpers

    /// Resolves an entity type ID by name and jurisdiction.
    /// Defaults to Multi Member LLC in Nevada if not found.
    private func resolveEntityType(for typeName: String, jurisdiction: String) async throws -> Int32? {
        // Look up jurisdiction
        guard
            let jurisdictionRecord = try await Jurisdiction.query(on: database)
                .filter(\.$name == jurisdiction)
                .first()
        else {
            return nil
        }

        let jurisdictionID = try jurisdictionRecord.requireID()

        // Map common type names
        let normalizedTypeName: String
        switch typeName.lowercased() {
        case "llc", "limited liability company":
            normalizedTypeName = "Multi Member LLC"
        case "single member llc":
            normalizedTypeName = "Single Member LLC"
        case "corporation", "c-corp", "c corp":
            normalizedTypeName = "C-Corp"
        case "s-corp", "s corp":
            normalizedTypeName = "S-Corp"
        default:
            normalizedTypeName = typeName
        }

        // Look up entity type
        if let entityType = try await EntityType.query(on: database)
            .filter(\.$name == normalizedTypeName)
            .filter(\.$jurisdiction.$id == jurisdictionID)
            .first()
        {
            return try entityType.requireID()
        }

        // Default to Multi Member LLC if not found
        if let defaultType = try await EntityType.query(on: database)
            .filter(\.$name == "Multi Member LLC")
            .filter(\.$jurisdiction.$id == jurisdictionID)
            .first()
        {
            return try defaultType.requireID()
        }

        return nil
    }
}
