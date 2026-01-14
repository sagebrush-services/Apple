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
    let isCompleted: Bool
    let currentStep: StateDescriptorDTO?
    let history: [StepHistoryDTO]

    enum FlowInstanceStatus: String, Codable, Hashable {
        case active
        case waiting
        case completed
        case cancelled
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
