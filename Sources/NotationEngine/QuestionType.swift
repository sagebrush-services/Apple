import Foundation

/// Canonical list of supported question input types for Sagebrush notations.
///
/// This mirrors the question type semantics used across Dali (server models)
/// and Sagebrush (client rendering). Centralising the definition here ensures
/// both applications stay in sync when new components are introduced.
public enum QuestionType: String, Codable, CaseIterable, Sendable {
    /// One line of text input
    case string
    /// Multi-line rich text stored via content-editable markup
    case text
    /// Date only (no time component)
    case date
    /// Combined date & time input
    case datetime
    /// Numeric value
    case number
    /// Boolean yes/no toggle
    case yesNo = "yes_no"
    /// Mutually exclusive selection rendered as radio buttons
    case radio
    /// Single-select dropdown
    case select
    /// Multi-select dropdown allowing multiple selections
    case multiSelect = "multi_select"
    /// Sensitive string such as SSNs or EINs
    case secret
    /// Phone number input that may trigger OTP validation
    case phone
    /// Email address input that may trigger OTP validation
    case email
    /// Social Security Number with specific mask validation
    case ssn
    /// Employer Identification Number with specific mask validation
    case ein
    /// File upload field
    case file
    /// Person record selector backed by directory search
    case person
    /// Physical mailing address selector/entry
    case address
    /// Organisation/entity selector
    case org
    /// Registered agent selector
    case registeredAgent = "registered_agent"
    /// Digital signature workflow trigger
    case signature
    /// Notarisation workflow trigger
    case notarization
    /// Document upload specifically for certified mail receipts
    case document
    /// Issuance selector for equity transactions
    case issuance
    /// Mailbox selector for postal routing
    case mailbox
}

extension QuestionType {
    /// Indicates whether the question expects a choice list provided by the
    /// question definition (radio/select/multiselect).
    public var requiresChoices: Bool {
        switch self {
        case .radio, .select, .multiSelect:
            return true
        default:
            return false
        }
    }

    /// Convenience for distinguishing trigger-style components that kick off
    /// downstream workflows instead of collecting raw values.
    public var isAction: Bool {
        switch self {
        case .signature, .notarization, .document:
            return true
        default:
            return false
        }
    }
}
