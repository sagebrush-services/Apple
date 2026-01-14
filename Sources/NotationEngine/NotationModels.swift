import Foundation

/// High-level representation of a notation file.
public struct Notation: Sendable, Hashable {
    public let metadata: Metadata
    public let document: Document?
    public let flow: StateMachine
    public let alignment: StateMachine?

    public init(
        metadata: Metadata,
        document: Document?,
        flow: StateMachine,
        alignment: StateMachine?
    ) {
        self.metadata = metadata
        self.document = document
        self.flow = flow
        self.alignment = alignment
    }

    /// Convenience accessor for the canonical code.
    public var code: String { metadata.code }
}

public extension Notation {
    struct Metadata: Sendable, Hashable {
        public let code: String
        public let title: String
        public let description: String?
        public let respondentType: RespondentType

        public init(
            code: String,
            title: String,
            description: String?,
            respondentType: RespondentType
        ) {
            self.code = code
            self.title = title
            self.description = description
            self.respondentType = respondentType
        }
    }

    struct Document: Sendable, Hashable {
        public let url: URL?
        public let type: DocumentType
        public let mappings: [String: DocumentMapping]

        public init(url: URL?, type: DocumentType, mappings: [String: DocumentMapping]) {
            self.url = url
            self.type = type
            self.mappings = mappings
        }
    }
}

public enum RespondentType: String, Codable, Sendable {
    case org
    case orgAndPerson = "org_and_person"
}

public enum DocumentType: String, Codable, Sendable {
    case pdf
    case markdown
}

/// Mapping instructions for filling a document with responses.
public struct DocumentMapping: Sendable, Hashable {
    public struct Point: Sendable, Hashable {
        public let x: Double
        public let y: Double

        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct Quad: Sendable, Hashable {
        public let upperLeft: Point
        public let lowerLeft: Point
        public let upperRight: Point
        public let lowerRight: Point

        public init(upperLeft: Point, lowerLeft: Point, upperRight: Point, lowerRight: Point) {
            self.upperLeft = upperLeft
            self.lowerLeft = lowerLeft
            self.upperRight = upperRight
            self.lowerRight = lowerRight
        }
    }

    public let field: String
    public let page: Int?
    public let quad: Quad?

    public init(field: String, page: Int?, quad: Quad?) {
        self.field = field
        self.page = page
        self.quad = quad
    }
}

/// Represents the parsed state machine describing a questionnaire flow.
public struct StateMachine: Sendable, Hashable {
    public struct Start: Sendable, Hashable {
        public let destination: Destination

        public init(destination: Destination) {
            self.destination = destination
        }
    }

    public struct Node: Sendable, Hashable {
        public let id: StateID
        public let question: QuestionReference
        public let transitions: [Transition]

        public init(id: StateID, question: QuestionReference, transitions: [Transition]) {
            self.id = id
            self.question = question
            self.transitions = transitions
        }
    }

    public struct Transition: Sendable, Hashable {
        public let condition: Condition
        public let destination: Destination

        public init(condition: Condition, destination: Destination) {
            self.condition = condition
            self.destination = destination
        }
    }

    public enum Condition: Sendable, Hashable {
        case any
        case choice(String)
    }

    public enum Destination: Sendable, Hashable {
        case state(StateID)
        case end
    }

    public struct StateID: RawRepresentable, Sendable, Hashable, Codable {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    public let start: Start
    public let nodes: [StateID: Node]

    public init(start: Start, nodes: [StateID: Node]) {
        self.start = start
        self.nodes = nodes
    }
}

/// Reference to a specific question, optionally scoped by contextual labels.
public struct QuestionReference: Sendable, Hashable, Codable {
    public let code: String
    public let contextTokens: [String]

    public init(code: String, contextTokens: [String]) {
        self.code = code
        self.contextTokens = contextTokens
    }

    /// Produces a human-friendly label derived from context tokens.
    public func resolvedLabel(defaultLabel: String? = nil) -> String? {
        guard !contextTokens.isEmpty else { return defaultLabel }
        return contextTokens
            .map { $0.replacingOccurrences(of: "_", with: " ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.capitalized }
            .joined(separator: " → ")
    }
}

// MARK: - Flow Execution Types

/// Runtime representation of a flow instance.
public struct FlowInstance: Sendable, Hashable {
    public let notation: Notation
    public let kind: FlowKind
    public var currentState: StateMachine.StateID?
    public var completed: Bool
    public var answerLog: [StateMachine.StateID: AnswerRecord]

    public init(notation: Notation, kind: FlowKind) {
        self.notation = notation
        self.kind = kind
        self.currentState = nil
        self.completed = false
        self.answerLog = [:]
    }

    public enum FlowKind: Sendable, Hashable {
        case client
        case alignment
    }

    public struct AnswerRecord: Sendable, Hashable {
        public let value: AnswerValue
        public let timestamp: Date

        public init(value: AnswerValue, timestamp: Date = Date()) {
            self.value = value
            self.timestamp = timestamp
        }
    }

    public enum AnswerValue: Sendable, Hashable {
        case string(String)
        case choice(String)
        case multiChoice([String])
        case payload(DataHash)
        case metadata([String: String])
    }

    public struct DataHash: Sendable, Hashable {
        public let algorithm: String
        public let value: String

        public init(algorithm: String, value: String) {
            self.algorithm = algorithm
            self.value = value
        }
    }
}
