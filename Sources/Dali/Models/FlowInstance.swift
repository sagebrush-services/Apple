import Fluent
import Foundation
import NotationEngine
import Vapor

public final class FlowInstanceRecord: Model, Content, @unchecked Sendable {
    public static let schema = "flow_instances"

    public enum Kind: String, Codable, Sendable {
        case client
        case alignment
    }

    public enum Status: String, Codable, Sendable {
        case started  // Questionnaire in progress (< 100%)
        case awaitingPayment  // Questionnaire complete, needs payment
        case preparingDocs  // Payment received, generating documents
        case awaitingNotary  // Documents ready, needs notarization
        case readyToFile  // Ready for Secretary of State filing
        case paperworkFiled  // Filed with SoS, awaiting confirmation
        case formed  // Entity confirmed and created in system
        case issue  // Problem occurred, needs attention
        case cancelled  // Cancelled by admin or user

        // Legacy statuses for backward compatibility
        case active  // Maps to 'started' for existing records
        case waiting  // Maps to 'awaitingPayment' for existing records
        case completed  // Maps to 'formed' for existing records
    }

    @ID(key: .id)
    public var id: UUID?

    @Field(key: "notation_code")
    public var notationCode: String

    @Enum(key: "kind")
    public var kind: Kind

    @Enum(key: "status")
    public var status: Status

    @Field(key: "current_state")
    public var currentState: String?

    @Field(key: "progress_stage")
    public var progressStage: String?

    @Field(key: "progress_percent")
    public var progressPercent: Double?

    @OptionalField(key: "respondent_entity_id")
    public var respondentEntityID: Int32?

    @OptionalField(key: "respondent_person_id")
    public var respondentPersonID: Int32?

    @Parent(key: "user_id")
    public var user: User

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    @Timestamp(key: "completed_at", on: .none)
    public var completedAt: Date?

    @OptionalParent(key: "mailbox_id")
    public var mailbox: Mailbox?

    @OptionalField(key: "generated_document_url")
    public var generatedDocumentURL: String?

    @OptionalField(key: "notarization_provider_id")
    public var notarizationProviderID: String?

    @OptionalField(key: "paid_at")
    public var paidAt: Date?

    @OptionalField(key: "filed_at")
    public var filedAt: Date?

    @OptionalField(key: "formed_at")
    public var formedAt: Date?

    @Children(for: \.$instance)
    public var steps: [FlowStepRecord]

    public init() {}

    public init(
        id: UUID? = nil,
        notationCode: String,
        kind: Kind,
        status: Status,
        currentState: String?,
        progressStage: String?,
        progressPercent: Double?,
        respondentEntityID: Int32?,
        respondentPersonID: Int32?,
        userID: Int32
    ) {
        self.id = id
        self.notationCode = notationCode
        self.kind = kind
        self.status = status
        self.currentState = currentState
        self.progressStage = progressStage
        self.progressPercent = progressPercent
        self.$user.id = userID
        self.respondentEntityID = respondentEntityID
        self.respondentPersonID = respondentPersonID
    }
}
