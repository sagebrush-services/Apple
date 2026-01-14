import Fluent
import FluentPostgresDriver
import Foundation
import PostgresNIO
import Vapor

/// Service for user profile operations
public struct UserRepository: Sendable {

    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func find(id: Int32) async throws -> User? {
        do {
            return try await User.find(id, on: database)
        } catch {
            throw RepositoryError.databaseError(error)
        }
    }

    public func findAll() async throws -> [User] {
        do {
            return try await User.query(on: database).all()
        } catch {
            throw RepositoryError.databaseError(error)
        }
    }

    public func create(model: User) async throws -> User {
        do {
            try await model.save(on: database)
            return model
        } catch {
            throw RepositoryError.databaseError(error)
        }
    }

    public func update(model: User) async throws -> User {
        do {
            try await model.save(on: database)
            return model
        } catch {
            throw RepositoryError.databaseError(error)
        }
    }

    public func delete(id: Int32) async throws {
        do {
            guard let user = try await find(id: id) else {
                throw RepositoryError.notFound
            }
            try await user.delete(on: database)
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.databaseError(error)
        }
    }
}
