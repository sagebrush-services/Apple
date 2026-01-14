import Foundation
import Logging

/// Local filesystem implementation of blob storage for development and testing.
///
/// This implementation stores blobs in a local directory structure, making it ideal
/// for development environments where AWS credentials aren't available or when
/// working offline. Files are organized in a hierarchy that mimics S3 key structure.
///
/// **Directory Structure:**
/// ```
/// {basePath}/
/// ├── blobs/
/// │   ├── 2024/01/15/
/// │   │   ├── uuid-1.ext
/// │   │   └── uuid-2.ext
/// │   └── metadata/
/// │       ├── uuid-1.json
/// │       └── uuid-2.json
/// ```
///
/// **Features:**
/// - Thread-safe operations using FileManager
/// - Automatic directory creation
/// - Metadata storage alongside blob data
/// - Date-based organization for easier navigation
/// - Atomic write operations to prevent corruption
public final class LocalFileSystemBlobStorage: BlobStorageProtocol, @unchecked Sendable {
    private let basePath: String
    private let fileManager: FileManager
    private let logger: Logger

    /// Initializes local filesystem blob storage.
    ///
    /// - Parameters:
    ///   - basePath: Root directory for blob storage (defaults to "tmp/blob-storage")
    ///   - fileManager: FileManager instance (defaults to .default)
    public init(basePath: String = "tmp/blob-storage", fileManager: FileManager = .default) {
        self.basePath = basePath
        self.fileManager = fileManager
        self.logger = Logger(label: "LocalFileSystemBlobStorage")

        // Ensure base directories exist
        createDirectoryStructure()

        logger.info("LocalFileSystemBlobStorage initialized at: \(basePath)")
    }

    public func store(data: Data, key: String, contentType: String) async throws -> String {
        let (blobPath, metadataPath) = generatePaths(for: key, contentType: contentType)
        let storageUrl = "file://\(blobPath)"

        // Create directory structure if needed
        let blobDir = URL(fileURLWithPath: blobPath).deletingLastPathComponent().path
        let metadataDir = URL(fileURLWithPath: metadataPath).deletingLastPathComponent().path

        do {
            try fileManager.createDirectory(atPath: blobDir, withIntermediateDirectories: true, attributes: nil)
            try fileManager.createDirectory(atPath: metadataDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.error("Failed to create directory structure: \(error)")
            throw BlobStorageError.storageFailure("Could not create storage directories: \(error.localizedDescription)")
        }

        do {
            // Write blob data atomically
            try data.write(to: URL(fileURLWithPath: blobPath), options: .atomic)

            // Create and store metadata
            let metadata = BlobMetadata(
                contentType: contentType,
                contentLength: Int64(data.count),
                lastModified: Date(),
                etag: calculateETag(for: data)
            )
            try await storeMetadata(metadata, at: metadataPath)

            logger.debug("Stored blob at: \(storageUrl)")
            return storageUrl
        } catch {
            logger.error("Failed to store blob: \(error)")
            throw BlobStorageError.storageFailure("Could not write blob data: \(error.localizedDescription)")
        }
    }

    public func retrieve(url: String) async throws -> Data? {
        guard let filePath = extractFilePath(from: url) else {
            throw BlobStorageError.invalidUrl(url)
        }

        guard fileManager.fileExists(atPath: filePath) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            logger.debug("Retrieved blob from: \(url)")
            return data
        } catch {
            logger.error("Failed to retrieve blob from \(url): \(error)")
            throw BlobStorageError.retrievalFailure("Could not read blob data: \(error.localizedDescription)")
        }
    }

    public func exists(url: String) async throws -> Bool {
        guard let filePath = extractFilePath(from: url) else {
            throw BlobStorageError.invalidUrl(url)
        }

        return fileManager.fileExists(atPath: filePath)
    }

    public func delete(url: String) async throws -> Bool {
        guard let filePath = extractFilePath(from: url) else {
            throw BlobStorageError.invalidUrl(url)
        }

        guard fileManager.fileExists(atPath: filePath) else {
            return false  // Already doesn't exist
        }

        do {
            try fileManager.removeItem(atPath: filePath)

            // Also delete metadata if it exists
            let key = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
            let (_, metadataPath) = generatePaths(for: key, contentType: "")
            if fileManager.fileExists(atPath: metadataPath) {
                try? fileManager.removeItem(atPath: metadataPath)
            }

            logger.debug("Deleted blob at: \(url)")
            return true
        } catch {
            logger.error("Failed to delete blob at \(url): \(error)")
            throw BlobStorageError.storageFailure("Could not delete blob: \(error.localizedDescription)")
        }
    }

    public func metadata(url: String) async throws -> BlobMetadata? {
        guard let filePath = extractFilePath(from: url) else {
            throw BlobStorageError.invalidUrl(url)
        }

        // Extract key from file path and generate metadata path
        let fileName = URL(fileURLWithPath: filePath).deletingPathExtension().lastPathComponent
        let (_, metadataPath) = generatePaths(for: fileName, contentType: "")

        guard fileManager.fileExists(atPath: metadataPath) else {
            // Fallback: create basic metadata from file attributes
            return try await createBasicMetadata(for: filePath)
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
            return try JSONDecoder().decode(BlobMetadata.self, from: data)
        } catch {
            logger.warning("Failed to read metadata, creating basic metadata: \(error)")
            return try await createBasicMetadata(for: filePath)
        }
    }

    // MARK: - Private Methods

    private func createDirectoryStructure() {
        let blobsDir = "\(basePath)/blobs"
        let metadataDir = "\(basePath)/metadata"

        try? fileManager.createDirectory(atPath: blobsDir, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(atPath: metadataDir, withIntermediateDirectories: true, attributes: nil)
    }

    private func generatePaths(for key: String, contentType: String) -> (blobPath: String, metadataPath: String) {
        // Use date-based organization
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let datePath = dateFormatter.string(from: Date())

        // Determine file extension from content type
        let fileExtension = fileExtension(for: contentType)
        let fileName = "\(key)\(fileExtension)"

        let blobPath = "\(basePath)/blobs/\(datePath)/\(fileName)"
        let metadataPath = "\(basePath)/metadata/\(datePath)/\(key).json"

        return (blobPath, metadataPath)
    }

    private func extractFilePath(from url: String) -> String? {
        guard url.hasPrefix("file://") else {
            return nil
        }
        return String(url.dropFirst(7))  // Remove "file://" prefix
    }

    private func fileExtension(for contentType: String) -> String {
        switch contentType.lowercased() {
        case "image/jpeg", "image/jpg":
            return ".jpg"
        case "image/png":
            return ".png"
        case "image/gif":
            return ".gif"
        case "application/pdf":
            return ".pdf"
        case "text/plain":
            return ".txt"
        case "text/html":
            return ".html"
        case "application/json":
            return ".json"
        case "text/csv":
            return ".csv"
        default:
            return ".dat"  // Generic data file
        }
    }

    private func calculateETag(for data: Data) -> String {
        // Simple hash-based ETag (similar to S3's approach for single-part uploads)
        let hash = data.withUnsafeBytes { bytes in
            var hasher = 0
            for byte in bytes {
                hasher = hasher &* 31 &+ Int(byte)
            }
            return hasher
        }
        return String(format: "%08x", abs(hash))
    }

    private func storeMetadata(_ metadata: BlobMetadata, at path: String) async throws {
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func createBasicMetadata(for filePath: String) async throws -> BlobMetadata? {
        guard fileManager.fileExists(atPath: filePath) else {
            return nil
        }

        do {
            let attributes = try fileManager.attributesOfItem(atPath: filePath)
            let fileSize = attributes[.size] as? Int64 ?? 0
            let modificationDate = attributes[.modificationDate] as? Date

            // Try to determine content type from file extension
            let fileExtension = URL(fileURLWithPath: filePath).pathExtension.lowercased()
            let contentType = contentType(for: fileExtension)

            return BlobMetadata(
                contentType: contentType,
                contentLength: fileSize,
                lastModified: modificationDate,
                etag: nil  // Can't calculate without reading the file
            )
        } catch {
            throw BlobStorageError.retrievalFailure("Could not read file attributes: \(error.localizedDescription)")
        }
    }

    private func contentType(for fileExtension: String) -> String {
        switch fileExtension {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "pdf":
            return "application/pdf"
        case "txt":
            return "text/plain"
        case "html":
            return "text/html"
        case "json":
            return "application/json"
        case "csv":
            return "text/csv"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - BlobMetadata Codable Support

extension BlobMetadata: Codable {
    enum CodingKeys: String, CodingKey {
        case contentType
        case contentLength
        case lastModified
        case etag
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.contentType = try container.decode(String.self, forKey: .contentType)
        self.contentLength = try container.decode(Int64.self, forKey: .contentLength)
        self.lastModified = try container.decode(Date.self, forKey: .lastModified)
        self.etag = try container.decode(String.self, forKey: .etag)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contentType, forKey: .contentType)
        try container.encode(contentLength, forKey: .contentLength)
        try container.encode(lastModified, forKey: .lastModified)
        try container.encode(etag, forKey: .etag)
    }
}
