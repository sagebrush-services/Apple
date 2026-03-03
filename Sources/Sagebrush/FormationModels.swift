import Foundation
import NotationEngine

struct NotationSummaryDTO: Codable, Identifiable, Hashable {
    let code: String
    let title: String
    let description: String?
    let respondentType: RespondentType
    let flowStateCount: Int
    let alignmentStateCount: Int

    var id: String { code }
}

struct QuestionDefinitionDTO: Codable, Hashable {
    let code: String
    let prompt: String
    let helpText: String?
    let type: QuestionType
    let choices: [ComponentChoiceDTO]

    struct ComponentChoiceDTO: Codable, Hashable {
        let value: String
        let label: String
    }

    func toDefinition() -> QuestionDefinition {
        QuestionDefinition(
            code: code,
            type: type,
            prompt: prompt,
            helpText: helpText,
            choices: choices.map { QuestionDefinition.Choice(value: $0.value, label: $0.label) }
        )
    }
}

struct FlowInstanceResponseDTO: Codable, Identifiable, Hashable {
    let id: UUID
    let notationCode: String
    let status: FlowInstanceStatus
    let kind: FlowInstanceKind
    let currentState: String?
    let progressStage: String?
    let progressPercent: Double?
    /// True when the questionnaire flow has reached an end state (no more questions).
    let isFlowComplete: Bool
    /// True only when the full formation lifecycle has completed (filed + confirmation received).
    let isFormationComplete: Bool
    /// Backwards compatible alias for `isFormationComplete`.
    let isCompleted: Bool
    let currentStep: StateDescriptorDTO?
    let history: [StepHistoryDTO]

    enum FlowInstanceStatus: Hashable, Codable {
        case started
        case awaitingPayment
        case preparingDocs
        case awaitingNotary
        case readyToFile
        case paperworkFiled
        case formed
        case issue
        case cancelled

        // Legacy values for backwards compatibility.
        case active
        case waiting
        case completed

        case unknown(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)

            switch raw {
            case "started": self = .started
            case "awaitingPayment": self = .awaitingPayment
            case "preparingDocs": self = .preparingDocs
            case "awaitingNotary": self = .awaitingNotary
            case "readyToFile": self = .readyToFile
            case "paperworkFiled": self = .paperworkFiled
            case "formed": self = .formed
            case "issue": self = .issue
            case "cancelled": self = .cancelled
            case "active": self = .active
            case "waiting": self = .waiting
            case "completed": self = .completed
            default: self = .unknown(raw)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        var rawValue: String {
            switch self {
            case .started: return "started"
            case .awaitingPayment: return "awaitingPayment"
            case .preparingDocs: return "preparingDocs"
            case .awaitingNotary: return "awaitingNotary"
            case .readyToFile: return "readyToFile"
            case .paperworkFiled: return "paperworkFiled"
            case .formed: return "formed"
            case .issue: return "issue"
            case .cancelled: return "cancelled"
            case .active: return "active"
            case .waiting: return "waiting"
            case .completed: return "completed"
            case .unknown(let value): return value
            }
        }
    }

    enum FlowInstanceKind: String, Codable, Hashable {
        case client
        case alignment
    }

    struct StepHistoryDTO: Codable, Hashable, Identifiable {
        let stateID: String
        let questionCode: String
        let answeredAt: Date?
        let actorRole: String

        var id: String { "\(stateID)-\(answeredAt?.timeIntervalSince1970 ?? 0)" }
    }
}

struct StateDescriptorDTO: Codable, Hashable {
    let id: String
    let questionCode: String
    let contextTokens: [String]
    let prompt: String
    let helpText: String?
    let component: ComponentMetadataDTO
}

struct ComponentMetadataDTO: Codable, Hashable {
    let kind: String
    let allowsMultipleSelection: Bool
    let choices: [QuestionDefinitionDTO.ComponentChoiceDTO]?
}
