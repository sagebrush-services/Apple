import Foundation

/// Service for managing formation status transitions with validation
public enum FormationStatusService {

    /// Error thrown when an invalid status transition is attempted
    public enum TransitionError: Error, LocalizedError, Equatable {
        case invalidTransition(from: FlowInstanceRecord.Status, to: FlowInstanceRecord.Status)
        case missingPayment
        case missingMailbox
        case missingDocument
        case missingNotarization

        public var errorDescription: String? {
            switch self {
            case .invalidTransition(let from, let to):
                return "Cannot transition from '\(from.rawValue)' to '\(to.rawValue)'"
            case .missingPayment:
                return "Payment is required before proceeding"
            case .missingMailbox:
                return "Mailbox must be assigned before proceeding"
            case .missingDocument:
                return "Document must be generated before proceeding"
            case .missingNotarization:
                return "Notarization must be completed before proceeding"
            }
        }
    }

    /// Validates whether a status transition is allowed
    /// - Parameters:
    ///   - from: Current status
    ///   - to: Target status
    /// - Returns: True if transition is valid
    /// - Throws: TransitionError if transition is not allowed
    public static func validateTransition(
        from: FlowInstanceRecord.Status,
        to: FlowInstanceRecord.Status
    ) throws {
        // Allow staying in same status (no-op)
        if from == to {
            return
        }

        // Map legacy statuses to new statuses for validation
        let normalizedFrom = normalizeLegacyStatus(from)
        let normalizedTo = normalizeLegacyStatus(to)

        // Allow transition to issue or cancelled from any status
        if normalizedTo == .issue || normalizedTo == .cancelled {
            return
        }

        // Define valid transitions
        let validTransitions: [FlowInstanceRecord.Status: Set<FlowInstanceRecord.Status>] = [
            .started: [.awaitingPayment, .issue, .cancelled],
            .awaitingPayment: [.preparingDocs, .issue, .cancelled],
            .preparingDocs: [.awaitingNotary, .issue, .cancelled],
            .awaitingNotary: [.readyToFile, .issue, .cancelled],
            .readyToFile: [.paperworkFiled, .issue, .cancelled],
            .paperworkFiled: [.formed, .issue, .cancelled],
            .formed: [],  // Terminal state (except issue/cancelled)
            .issue: [.started, .awaitingPayment, .preparingDocs, .awaitingNotary, .readyToFile, .paperworkFiled, .cancelled],  // Can retry from issue
            .cancelled: [],  // Terminal state
        ]

        guard let allowedTransitions = validTransitions[normalizedFrom],
              allowedTransitions.contains(normalizedTo) else {
            throw TransitionError.invalidTransition(from: from, to: to)
        }
    }

    /// Validates that required fields are present for a status transition
    /// - Parameters:
    ///   - formation: The formation record to validate
    ///   - newStatus: The target status
    /// - Throws: TransitionError if required fields are missing
    public static func validateRequiredFields(
        formation: FlowInstanceRecord,
        newStatus: FlowInstanceRecord.Status
    ) throws {
        let normalized = normalizeLegacyStatus(newStatus)

        switch normalized {
        case .preparingDocs:
            // Requires payment timestamp
            guard formation.paidAt != nil else {
                throw TransitionError.missingPayment
            }

        case .awaitingNotary:
            // Requires mailbox assignment and generated document
            guard formation.$mailbox.id != nil else {
                throw TransitionError.missingMailbox
            }
            guard formation.generatedDocumentURL != nil else {
                throw TransitionError.missingDocument
            }

        case .readyToFile:
            // Requires notarization provider ID
            guard formation.notarizationProviderID != nil else {
                throw TransitionError.missingNotarization
            }

        case .paperworkFiled:
            // Requires filing timestamp
            guard formation.filedAt != nil else {
                throw TransitionError.invalidTransition(
                    from: formation.status,
                    to: newStatus
                )
            }

        case .formed:
            // Requires formation timestamp
            guard formation.formedAt != nil else {
                throw TransitionError.invalidTransition(
                    from: formation.status,
                    to: newStatus
                )
            }

        default:
            break
        }
    }

    /// Returns all valid next statuses for the current status
    /// - Parameter status: Current status
    /// - Returns: Array of valid next statuses
    public static func allowedTransitions(from status: FlowInstanceRecord.Status) -> [FlowInstanceRecord.Status] {
        let normalized = normalizeLegacyStatus(status)

        let transitions: [FlowInstanceRecord.Status: [FlowInstanceRecord.Status]] = [
            .started: [.awaitingPayment, .issue, .cancelled],
            .awaitingPayment: [.preparingDocs, .issue, .cancelled],
            .preparingDocs: [.awaitingNotary, .issue, .cancelled],
            .awaitingNotary: [.readyToFile, .issue, .cancelled],
            .readyToFile: [.paperworkFiled, .issue, .cancelled],
            .paperworkFiled: [.formed, .issue, .cancelled],
            .formed: [.issue, .cancelled],
            .issue: [.started, .awaitingPayment, .preparingDocs, .awaitingNotary, .readyToFile, .paperworkFiled, .cancelled],
            .cancelled: [],
        ]

        return transitions[normalized] ?? []
    }

    /// Normalizes legacy status values to their new equivalents
    /// - Parameter status: Status to normalize
    /// - Returns: Normalized status
    private static func normalizeLegacyStatus(_ status: FlowInstanceRecord.Status) -> FlowInstanceRecord.Status {
        switch status {
        case .active:
            return .started
        case .waiting:
            return .awaitingPayment
        case .completed:
            return .formed
        default:
            return status
        }
    }

    /// Human-readable display name for status
    /// - Parameter status: Status to display
    /// - Returns: Display name
    public static func displayName(for status: FlowInstanceRecord.Status) -> String {
        switch status {
        case .started, .active:
            return "Started"
        case .awaitingPayment, .waiting:
            return "Awaiting Payment"
        case .preparingDocs:
            return "Preparing Documents"
        case .awaitingNotary:
            return "Awaiting Notarization"
        case .readyToFile:
            return "Ready to File"
        case .paperworkFiled:
            return "Paperwork Filed"
        case .formed, .completed:
            return "Formed"
        case .issue:
            return "Issue"
        case .cancelled:
            return "Cancelled"
        }
    }
}
