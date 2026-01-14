import Fluent
import Foundation
import NotationEngine
import Vapor

public final class FlowStepRecord: Model, Content, @unchecked Sendable {
    public static let schema = "flow_steps"

    public enum ActorRole: String, Codable, Sendable {
        case client
        case staff
        case system
    }

    public enum AnswerType: String, Codable, Sendable {
        case string
        case choice
        case multiChoice
        case payload
        case metadata

        public init(from value: FlowInstance.AnswerValue) {
            switch value {
            case .string:
                self = .string
            case .choice:
                self = .choice
            case .multiChoice:
                self = .multiChoice
            case .payload:
                self = .payload
            case .metadata:
                self = .metadata
            }
        }
    }

    @ID(key: .id)
    public var id: UUID?

    @Parent(key: "instance_id")
    public var instance: FlowInstanceRecord

    @Field(key: "state_id")
    public var stateID: String

    @Field(key: "question_code")
    public var questionCode: String

    @Field(key: "context_tokens")
    public var contextTokens: [String]

    @Field(key: "answer_payload")
    public var answerPayload: AnswerContainer

    @Enum(key: "answer_type")
    public var answerType: AnswerType

    @Enum(key: "actor_role")
    public var actorRole: ActorRole

    @OptionalField(key: "actor_user_id")
    public var actorUserID: Int32?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    public init() {}

    public init(
        id: UUID? = nil,
        instanceID: UUID,
        stateID: String,
        questionCode: String,
        contextTokens: [String],
        answer: FlowInstance.AnswerValue,
        actorRole: ActorRole,
        actorUserID: Int32?
    ) throws {
        self.id = id
        self.$instance.id = instanceID
        self.stateID = stateID
        self.questionCode = questionCode
        self.contextTokens = contextTokens
        self.answerType = AnswerType(from: answer)
        self.answerPayload = try AnswerContainer(value: answer)
        self.actorRole = actorRole
        self.actorUserID = actorUserID
    }
}

// MARK: - Codable container for persisted answers

public struct AnswerContainer: Codable, Sendable, Hashable {
    public let stringValue: String?
    public let choiceValue: String?
    public let multiChoiceValue: [String]?
    public let payload: PayloadInfo?
    public let metadata: [String: String]?

    public init(string: String) {
        self.stringValue = string
        self.choiceValue = nil
        self.multiChoiceValue = nil
        self.payload = nil
        self.metadata = nil
    }

    public init(choice: String) {
        self.stringValue = nil
        self.choiceValue = choice
        self.multiChoiceValue = nil
        self.payload = nil
        self.metadata = nil
    }

    public init(multiChoice: [String]) {
        self.stringValue = nil
        self.choiceValue = nil
        self.multiChoiceValue = multiChoice
        self.payload = nil
        self.metadata = nil
    }

    public init(payload: FlowInstance.DataHash) {
        self.stringValue = nil
        self.choiceValue = nil
        self.multiChoiceValue = nil
        self.payload = .init(algorithm: payload.algorithm, value: payload.value)
        self.metadata = nil
    }

    public init(metadata: [String: String]) {
        self.stringValue = nil
        self.choiceValue = nil
        self.multiChoiceValue = nil
        self.payload = nil
        self.metadata = metadata
    }

    public init(value: FlowInstance.AnswerValue) throws {
        switch value {
        case .string(let s):
            self = AnswerContainer(string: s)
        case .choice(let c):
            self = AnswerContainer(choice: c)
        case .multiChoice(let array):
            self = AnswerContainer(multiChoice: array)
        case .payload(let hash):
            self = AnswerContainer(payload: hash)
        case .metadata(let map):
            self = AnswerContainer(metadata: map)
        }
    }

    public func asAnswerValue() -> FlowInstance.AnswerValue {
        if let stringValue {
            return .string(stringValue)
        }
        if let choiceValue {
            return .choice(choiceValue)
        }
        if let multiChoiceValue {
            return .multiChoice(multiChoiceValue)
        }
        if let payload {
            return .payload(.init(algorithm: payload.algorithm, value: payload.value))
        }
        return .metadata(metadata ?? [:])
    }

    public struct PayloadInfo: Codable, Sendable, Hashable {
        public let algorithm: String
        public let value: String
    }
}
