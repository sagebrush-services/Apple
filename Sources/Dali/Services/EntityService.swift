import Fluent
import Foundation

public actor EntityService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    public func listAll() async throws -> [Entity] {
        try await Entity.query(on: database).all()
    }
}
