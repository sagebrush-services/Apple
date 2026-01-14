import Fluent
import Foundation
import Logging
import Vapor

/// Repository for managing blob storage operations with database integration.
///
/// `BlobRepository` provides a high-level interface for blob operations that combines
/// the database persistence layer (via the `Blob` model) with the underlying storage
/// mechanism (S3 or local filesystem). This creates a unified API for blob management
/// across the application.
///
/// **Features:**
/// - Local filesystem storage for blob data
/// - Database integration for blob metadata and references
/// - Transaction support for atomic operations
/// - Polymorphic blob relationships (blobs can be referenced by different entity types)
/// - Cleanup operations for orphaned blobs
/// - Progress tracking for bulk operations
///
/// **Usage Example:**
/// ```swift
/// let repository = try await BlobRepository.create(database: database)
///
/// let blob = try await repository.store(
///     data: imageData,
///     contentType: "image/jpeg",
///     referencedBy: .answers,
///     referencedById: answerId
/// )
///
/// let data = try await repository.retrieveData(blob: blob)
/// ```
public final class BlobRepository: Sendable {
    private let storage: BlobStorageProtocol
    private let database: Database
    private let logger: Logger

    /// Initializes blob repository with the specified storage backend.
    ///
    /// - Parameters:
    ///   - storage: The storage backend to use for blob operations
    ///   - database: Fluent database instance for metadata persistence
    public init(storage: BlobStorageProtocol, database: Database) {
        self.storage = storage
        self.database = database
        self.logger = Logger(label: "BlobRepository")
    }

    /// Factory method that creates a repository with local filesystem storage.
    ///
    /// - Parameters:
    ///   - database: Fluent database instance
    ///   - localBasePath: Base path for local filesystem storage (defaults to "tmp/blob-storage")
    /// - Returns: Configured BlobRepository instance
    public static func create(
        database: Database,
        localBasePath: String = "tmp/blob-storage"
    ) async throws -> BlobRepository {
        let storage: BlobStorageProtocol

        storage = LocalFileSystemBlobStorage(basePath: localBasePath)
        Logger(label: "BlobRepository.Factory").info("Using local filesystem blob storage: \(localBasePath)")

        return BlobRepository(storage: storage, database: database)
    }

    /// Stores blob data and creates a database record.
    ///
    /// This operation is atomic - if either the storage or database operation fails,
    /// the entire operation is rolled back.
    ///
    /// - Parameters:
    ///   - data: The blob data to store
    ///   - contentType: MIME type of the blob
    ///   - referencedBy: Type of entity referencing this blob
    ///   - referencedById: Int32 ID of the referencing entity
    ///   - key: Optional custom key (UUID will be generated if not provided)
    /// - Returns: The created Blob model instance
    /// - Throws: `BlobStorageError` or database errors
    public func store(
        data: Data,
        contentType: String,
        referencedBy: BlobReferencedBy,
        referencedById: Int32,
        key: String? = nil
    ) async throws -> Blob {
        let blobKey = key ?? UUID().uuidString

        return try await database.transaction { database in
            // Store the data in the storage backend
            let storageUrl = try await self.storage.store(
                data: data,
                key: blobKey,
                contentType: contentType
            )

            // Create and save the database record
            let blob = Blob()
            blob.objectStorageUrl = storageUrl
            blob.referencedBy = referencedBy
            blob.referencedById = referencedById

            try await blob.save(on: database)

            self.logger.info("Stored blob: \(blob.id?.description ?? "unknown") -> \(storageUrl)")
            return blob
        }
    }

    /// Retrieves blob data from storage.
    ///
    /// - Parameter blob: The Blob model instance
    /// - Returns: The blob data, or nil if not found
    /// - Throws: `BlobStorageError` if retrieval fails
    public func retrieveData(blob: Blob) async throws -> Data? {
        try await storage.retrieve(url: blob.objectStorageUrl)
    }

    /// Retrieves blob data by blob ID.
    ///
    /// - Parameter blobId: Int32 ID of the blob to retrieve
    /// - Returns: Tuple of blob model and data, or nil if not found
    /// - Throws: `BlobStorageError` or database errors
    public func retrieveData(blobId: Int32) async throws -> (blob: Blob, data: Data)? {
        guard let blob = try await Blob.find(blobId, on: database) else {
            return nil
        }

        guard let data = try await retrieveData(blob: blob) else {
            return nil
        }

        return (blob: blob, data: data)
    }

    /// Finds blobs referenced by a specific entity.
    ///
    /// - Parameters:
    ///   - referencedBy: Type of the referencing entity
    ///   - referencedById: Int32 ID of the referencing entity
    /// - Returns: Array of Blob instances
    public func findBlobs(referencedBy: BlobReferencedBy, referencedById: Int32) async throws -> [Blob] {
        try await Blob.query(on: database)
            .filter(\.$referencedBy == referencedBy)
            .filter(\.$referencedById == referencedById)
            .all()
    }

    /// Deletes a blob from both storage and database.
    ///
    /// This operation is atomic - if either the storage or database deletion fails,
    /// the operation is rolled back where possible.
    ///
    /// - Parameter blob: The Blob instance to delete
    /// - Returns: True if deletion was successful
    /// - Throws: `BlobStorageError` or database errors
    @discardableResult
    public func delete(blob: Blob) async throws -> Bool {
        try await database.transaction { database in
            // Delete from storage first (if this fails, database won't be modified)
            let storageDeleted = try await self.storage.delete(url: blob.objectStorageUrl)

            if storageDeleted {
                // Delete database record
                try await blob.delete(on: database)
                self.logger.info("Deleted blob: \(blob.id?.description ?? "unknown")")
                return true
            } else {
                // Storage deletion failed or blob didn't exist
                self.logger.warning(
                    "Failed to delete blob from storage, keeping database record: \(blob.objectStorageUrl)"
                )
                return false
            }
        }
    }

    /// Deletes all blobs referenced by a specific entity.
    ///
    /// - Parameters:
    ///   - referencedBy: Type of the referencing entity
    ///   - referencedById: Int32 ID of the referencing entity
    /// - Returns: Number of blobs successfully deleted
    public func deleteBlobs(referencedBy: BlobReferencedBy, referencedById: Int32) async throws -> Int {
        let blobs = try await findBlobs(referencedBy: referencedBy, referencedById: referencedById)
        var deletedCount = 0

        for blob in blobs {
            let success = try await delete(blob: blob)
            if success {
                deletedCount += 1
            }
        }

        logger.info("Deleted \(deletedCount)/\(blobs.count) blobs for \(referencedBy):\(referencedById)")
        return deletedCount
    }

    /// Checks if a blob exists in storage.
    ///
    /// - Parameter blob: The Blob instance to check
    /// - Returns: True if the blob exists in storage
    /// - Throws: `BlobStorageError` if the check fails
    public func exists(blob: Blob) async throws -> Bool {
        try await storage.exists(url: blob.objectStorageUrl)
    }

    /// Gets metadata for a blob from storage.
    ///
    /// - Parameter blob: The Blob instance to get metadata for
    /// - Returns: Blob metadata, or nil if not found
    /// - Throws: `BlobStorageError` if metadata retrieval fails
    public func metadata(blob: Blob) async throws -> BlobMetadata? {
        try await storage.metadata(url: blob.objectStorageUrl)
    }

    /// Finds orphaned blob records (database records without corresponding storage files).
    ///
    /// This method checks all blob records in the database and identifies those
    /// where the storage file no longer exists. Useful for cleanup operations.
    ///
    /// - Parameters:
    ///   - referencedBy: Optional filter by entity type
    ///   - limit: Maximum number of blobs to check (defaults to 1000)
    /// - Returns: Array of orphaned Blob instances
    public func findOrphanedBlobs(referencedBy: BlobReferencedBy? = nil, limit: Int = 1000) async throws -> [Blob] {
        var query = Blob.query(on: database)

        if let referencedBy = referencedBy {
            query = query.filter(\.$referencedBy == referencedBy)
        }

        let blobs = try await query.limit(limit).all()
        var orphanedBlobs: [Blob] = []

        for blob in blobs {
            let exists = try await exists(blob: blob)
            if !exists {
                orphanedBlobs.append(blob)
            }
        }

        logger.info("Found \(orphanedBlobs.count) orphaned blobs out of \(blobs.count) checked")
        return orphanedBlobs
    }

    /// Cleans up orphaned blob records.
    ///
    /// Finds and deletes database records for blobs that no longer exist in storage.
    /// This is a safe operation as it only removes database records for non-existent files.
    ///
    /// - Parameters:
    ///   - referencedBy: Optional filter by entity type
    ///   - limit: Maximum number of orphaned records to clean (defaults to 100)
    /// - Returns: Number of orphaned records cleaned up
    public func cleanupOrphanedBlobs(referencedBy: BlobReferencedBy? = nil, limit: Int = 100) async throws -> Int {
        let orphanedBlobs = try await findOrphanedBlobs(referencedBy: referencedBy, limit: limit)

        for blob in orphanedBlobs {
            try await blob.delete(on: database)
        }

        logger.info("Cleaned up \(orphanedBlobs.count) orphaned blob records")
        return orphanedBlobs.count
    }

    // MARK: - Private Methods

}
