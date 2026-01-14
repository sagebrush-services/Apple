import Fluent

protocol RepositoryProtocol {
    associatedtype ID: Hashable

    func find(id: ID) async throws -> (any Model)?
    func findAll() async throws -> [any Model]
    func create(model: any Model) async throws -> any Model
    func update(model: any Model) async throws -> any Model
    func delete(id: ID) async throws
}

enum RepositoryError: Error {
    case notFound
    case alreadyExists
    case invalidModel
    case databaseError(Error)
}
