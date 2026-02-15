import Foundation

/// Representation of a reusable question definition that can be supplied by
/// either the server (Bazaar) or client applications (Sagebrush).
public struct QuestionDefinition: Sendable, Hashable {
    public struct Choice: Sendable, Hashable {
        public let value: String
        public let label: String

        public init(value: String, label: String) {
            self.value = value
            self.label = label
        }
    }

    public let code: String
    public let type: QuestionType
    public let prompt: String
    public let helpText: String?
    public let choices: [Choice]

    public init(
        code: String,
        type: QuestionType,
        prompt: String,
        helpText: String?,
        choices: [Choice] = []
    ) {
        self.code = code
        self.type = type
        self.prompt = prompt
        self.helpText = helpText
        self.choices = choices
    }
}

/// Runtime descriptor of a question step tailored to a particular notation
/// context (e.g. `registered_agent__for_company`).
public struct QuestionStepDescriptor: Sendable, Hashable {
    public let reference: QuestionReference
    public let definition: QuestionDefinition
    public let displayPrompt: String
    public let displayHelp: String?
    public let component: Component

    public init(
        reference: QuestionReference,
        definition: QuestionDefinition,
        displayPrompt: String,
        displayHelp: String?,
        component: Component
    ) {
        self.reference = reference
        self.definition = definition
        self.displayPrompt = displayPrompt
        self.displayHelp = displayHelp
        self.component = component
    }

    /// High-level component categories that UI layers can use to render native
    /// controls (SwiftUI, Bulma forms, etc.).
    public enum Component: Sendable, Hashable {
        case singleLineText
        case multiLineText
        case integer
        case decimal
        case toggle
        case radio([QuestionDefinition.Choice])
        case picker([QuestionDefinition.Choice])
        case multiSelect([QuestionDefinition.Choice])
        case date
        case dateTime
        case secret
        case phone
        case email
        case ssn
        case ein
        case fileUpload
        case personLookup
        case addressEntry
        case organizationLookup
        case registeredAgent
        case signatureRequest
        case notarizationRequest
        case documentUpload
        case issuanceLookup
        case mailboxSelect
    }
}

public enum QuestionComponentFactory {
    /// Builds a descriptor for the given question reference using the provided
    /// definition. Placeholder tokens like `{{for_label}}` are expanded using
    /// the notation context.
    public static func makeDescriptor(
        reference: QuestionReference,
        definition: QuestionDefinition
    ) -> QuestionStepDescriptor {
        // Provide a sensible default label when no context tokens are available
        let defaultLabel = inferDefaultLabel(from: reference.code)
        let contextLabel = reference.resolvedLabel(defaultLabel: defaultLabel)

        let prompt = replacePlaceholders(in: definition.prompt, contextLabel: contextLabel)
        let help = definition.helpText.map { replacePlaceholders(in: $0, contextLabel: contextLabel) }

        let component = component(for: definition.type, choices: definition.choices)

        return QuestionStepDescriptor(
            reference: reference,
            definition: definition,
            displayPrompt: prompt,
            displayHelp: help,
            component: component
        )
    }

    private static func replacePlaceholders(in text: String, contextLabel: String?) -> String {
        guard let contextLabel else { return text }
        let formatted = contextLabel
        return
            text
            .replacingOccurrences(of: "{{for_label}}", with: formatted)
            .replacingOccurrences(of: "{{parent_label}}", with: formatted)
            .replacingOccurrences(of: "{{label}}", with: formatted)
    }

    /// Infers a sensible default label based on the question code when no context tokens are available
    private static func inferDefaultLabel(from questionCode: String) -> String {
        // Common patterns for inferring what entity we're referring to
        switch questionCode {
        case _ where questionCode.contains("entity"), _ where questionCode.contains("org"):
            return "this entity"
        case _ where questionCode.contains("person"), _ where questionCode.contains("individual"):
            return "this person"
        case _ where questionCode.contains("agent"):
            return "this LLC"
        case _ where questionCode.contains("application"), _ where questionCode.contains("annual"):
            return "this application"
        default:
            return "this entity"
        }
    }

    private static func component(
        for type: QuestionType,
        choices: [QuestionDefinition.Choice]
    ) -> QuestionStepDescriptor.Component {
        switch type {
        case .string:
            return .singleLineText
        case .text:
            return .multiLineText
        case .date:
            return .date
        case .datetime:
            return .dateTime
        case .number:
            return .decimal
        case .yesNo:
            return .toggle
        case .radio:
            return .radio(choices)
        case .select:
            return .picker(choices)
        case .multiSelect:
            return .multiSelect(choices)
        case .secret:
            return .secret
        case .phone:
            return .phone
        case .email:
            return .email
        case .ssn:
            return .ssn
        case .ein:
            return .ein
        case .file:
            return .fileUpload
        case .person:
            return .personLookup
        case .address:
            return .addressEntry
        case .org:
            return .organizationLookup
        case .registeredAgent:
            return .registeredAgent
        case .signature:
            return .signatureRequest
        case .notarization:
            return .notarizationRequest
        case .document:
            return .documentUpload
        case .issuance:
            return .issuanceLookup
        case .mailbox:
            return .mailboxSelect
        }
    }
}
