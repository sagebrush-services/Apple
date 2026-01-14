import Fluent
import Foundation
import Vapor

public enum MailItemStatus: String, Codable, CaseIterable, Sendable {
    case pendingVerification = "pending_verification"
    case needsReview = "needs_review"
    case confirmed = "confirmed"
}

/// Digitized mail scanned by the Sagebrush mailroom.
public final class MailItem: Model, @unchecked Sendable {
    public static let schema = "mail_items"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    /// Mailbox that physically received the item.
    @Parent(key: "mailbox_id")
    public var mailbox: Mailbox

    /// Entity the document belongs to (optional in case of personal mail).
    @OptionalParent(key: "entity_id")
    public var entity: Entity?

    /// User who uploaded the scan (mailroom staff).
    @OptionalParent(key: "uploader_id")
    public var uploader: User?

    /// Storage key (S3 path or MinIO key).
    @Field(key: "storage_key")
    public var storageKey: String

    /// Original filename provided by the uploader.
    @Field(key: "filename")
    public var filename: String

    /// MIME type detected for the upload.
    @Field(key: "content_type")
    public var contentType: String

    /// Current workflow status of the mail item.
    @Enum(key: "status")
    public var status: MailItemStatus

    /// Optional free-form notes provided by staff.
    @OptionalField(key: "notes")
    public var notes: String?

    /// Timestamp when the mail physically arrived (if known).
    @OptionalField(key: "received_at")
    public var receivedAt: Date?

    /// Timestamp when the digitized file was processed/cleared.
    @OptionalField(key: "processed_at")
    public var processedAt: Date?

    /// Confidence (0-1) reported by the AI verification, if available.
    @OptionalField(key: "ai_confidence")
    public var aiConfidence: Double?

    /// Human-readable explanation from AI verification.
    @OptionalField(key: "ai_notes")
    public var aiNotes: String?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}
}
