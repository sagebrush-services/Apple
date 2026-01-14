import Fluent
import Foundation
import Vapor

/// Service layer for managing Person entities with CRUD operations.
///
/// This service provides a clean interface for Person management,
/// handling all database operations and business logic.
public actor PeopleService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Creates a new person in the database.
    ///
    /// - Parameters:
    ///   - name: The person's full name
    ///   - email: The person's email address (must be unique)
    /// - Returns: The created Person
    /// - Throws: Database errors or validation errors
    public func create(
        name: String,
        email: String
    ) async throws -> Person {
        let person = Person()
        person.name = name
        person.email = email

        try await person.save(on: database)
        return person
    }

    /// Retrieves all people from the database.
    ///
    /// - Parameter sortByName: If true, sorts people by name alphabetically
    /// - Returns: Array of all people
    /// - Throws: Database errors
    public func list(sortByName: Bool = false) async throws -> [Person] {
        let query = Person.query(on: database)

        if sortByName {
            return try await query.sort(\.$name).all()
        }

        return try await query.all()
    }

    /// Retrieves a specific person by ID.
    ///
    /// - Parameter id: The person ID
    /// - Returns: The requested person
    /// - Throws: Not found error or database errors
    public func get(id: Int32) async throws -> Person {
        guard let person = try await Person.find(id, on: database) else {
            throw Abort(.notFound, reason: "Person with ID \(id) not found")
        }
        return person
    }

    /// Retrieves a specific person by email.
    ///
    /// - Parameter email: The unique email address
    /// - Returns: The requested person
    /// - Throws: Not found error or database errors
    public func getByEmail(_ email: String) async throws -> Person {
        guard
            let person = try await Person.query(on: database)
                .filter(\.$email == email)
                .first()
        else {
            throw Abort(.notFound, reason: "Person with email '\(email)' not found")
        }
        return person
    }

    /// Updates an existing person.
    ///
    /// - Parameters:
    ///   - id: The person ID to update
    ///   - name: New name (optional)
    ///   - email: New email (optional)
    /// - Returns: The updated person
    /// - Throws: Not found error or database errors
    public func update(
        id: Int32,
        name: String? = nil,
        email: String? = nil
    ) async throws -> Person {
        guard let person = try await Person.find(id, on: database) else {
            throw Abort(.notFound, reason: "Person with ID \(id) not found")
        }

        if let name = name {
            person.name = name
        }
        if let email = email {
            person.email = email
        }

        try await person.save(on: database)
        return person
    }

    /// Deletes a person from the database.
    ///
    /// - Parameter id: The person ID to delete
    /// - Throws: Not found error or database errors
    public func delete(id: Int32) async throws {
        guard let person = try await Person.find(id, on: database) else {
            throw Abort(.notFound, reason: "Person with ID \(id) not found")
        }

        try await person.delete(on: database)
    }
}

/// Request/Response DTOs for Person endpoints

/// Request structure for creating a new person.
public struct CreatePersonRequest: Content, Validatable {
    public let name: String
    public let email: String

    public init(
        name: String,
        email: String
    ) {
        self.name = name
        self.email = email
    }

    public static func validations(_ validations: inout Validations) {
        validations.add("name", as: String.self, is: !.empty)
        validations.add("email", as: String.self, is: .email && !.empty)
    }
}

/// Request structure for updating an existing person.
public struct UpdatePersonRequest: Content {
    public let name: String?
    public let email: String?

    public init(
        name: String? = nil,
        email: String? = nil
    ) {
        self.name = name
        self.email = email
    }
}

/// Response structure for a person.
public struct PersonResponse: Content {
    public let id: Int32
    public let name: String
    public let email: String
    public let insertedAt: Date?
    public let updatedAt: Date?

    public init(from person: Person) {
        self.id = person.id ?? 0
        self.name = person.name
        self.email = person.email
        self.insertedAt = person.insertedAt
        self.updatedAt = person.updatedAt
    }
}
