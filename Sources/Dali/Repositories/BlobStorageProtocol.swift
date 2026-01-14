import Foundation

/// Protocol for blob storage operations, abstracting the underlying storage mechanism.
///
/// This protocol provides a unified interface for storing and retrieving blobs,
/// allowing the application to work with different storage backends (S3, local filesystem, etc.)
/// without changing business logic.
///
/// **Implementation Requirements:**
/// - All operations should be thread-safe and support concurrent access
/// - Storage URLs should be consistent and predictable
/// - Failed operations should throw descriptive errors
/// - Implementations should handle cleanup of temporary files/resources
public protocol BlobStorageProtocol: Sendable {

    /// Stores blob data and returns a storage URL.
    ///
    /// - Parameters:
    ///   - data: The blob data to store
    ///   - key: A unique identifier for the blob (will be used in the storage path)
    ///   - contentType: MIME type of the blob data
    /// - Returns: A storage URL that can be used to retrieve the blob
    /// - Throws: `BlobStorageError` if storage operation fails
    func store(data: Data, key: String, contentType: String) async throws -> String

    /// Retrieves blob data from storage.
    ///
    /// - Parameter url: The storage URL returned by `store`
    /// - Returns: The blob data, or nil if not found
    /// - Throws: `BlobStorageError` if retrieval operation fails
    func retrieve(url: String) async throws -> Data?

    /// Checks if a blob exists at the given URL.
    ///
    /// - Parameter url: The storage URL to check
    /// - Returns: True if the blob exists, false otherwise
    /// - Throws: `BlobStorageError` if the check operation fails
    func exists(url: String) async throws -> Bool

    /// Deletes a blob from storage.
    ///
    /// - Parameter url: The storage URL of the blob to delete
    /// - Returns: True if deletion was successful, false if blob didn't exist
    /// - Throws: `BlobStorageError` if deletion operation fails
    func delete(url: String) async throws -> Bool

    /// Returns metadata about a stored blob.
    ///
    /// - Parameter url: The storage URL to get metadata for
    /// - Returns: Metadata about the blob, or nil if not found
    /// - Throws: `BlobStorageError` if metadata retrieval fails
    func metadata(url: String) async throws -> BlobMetadata?
}

/// Metadata information about a stored blob.
public struct BlobMetadata: Sendable {
    public let contentType: String
    public let contentLength: Int64
    public let lastModified: Date?
    public let etag: String?

    public init(contentType: String, contentLength: Int64, lastModified: Date? = nil, etag: String? = nil) {
        self.contentType = contentType
        self.contentLength = contentLength
        self.lastModified = lastModified
        self.etag = etag
    }
}

/// Errors that can occur during blob storage operations.
public enum BlobStorageError: Error, LocalizedError, Sendable {
    case storageFailure(String)
    case retrievalFailure(String)
    case notFound(String)
    case invalidUrl(String)
    case permissionDenied(String)
    case insufficientStorage(String)

    public var errorDescription: String? {
        switch self {
        case .storageFailure(let message):
            return "Blob storage failed: \(message)"
        case .retrievalFailure(let message):
            return "Blob retrieval failed: \(message)"
        case .notFound(let url):
            return "Blob not found at URL: \(url)"
        case .invalidUrl(let url):
            return "Invalid storage URL: \(url)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .insufficientStorage(let message):
            return "Insufficient storage space: \(message)"
        }
    }
}
