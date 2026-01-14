import Foundation
import Yams

/// Parses YAML notation files into strongly typed `Notation` models.
public enum NotationParser {
    public static func parse(yaml: String, source: URL? = nil) throws -> Notation {
        do {
            let decoder = YAMLDecoder()
            let raw = try decoder.decode(RawNotation.self, from: yaml)
            return try raw.buildNotation()
        } catch let error as DecodingError {
            throw NotationError.invalidYAML(String(describing: error))
        } catch let error as YamlError {
            throw NotationError.invalidYAML(error.localizedDescription)
        } catch {
            throw NotationError.invalidYAML(error.localizedDescription)
        }
    }
}

// MARK: - Raw Model Definitions

private struct RawNotation: Decodable {
    let code: String
    let title: String
    let description: String?
    let respondent_type: String?
    let document_url: String?
    let document_type: String?
    let document_mappings: [String: RawDocumentMapping]?
    let flow: [String: [String: String]]
    let alignment: [String: [String: String]]?

    func buildNotation() throws -> Notation {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NotationError.missingField("code")
        }

        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NotationError.missingField("title")
        }

        let respondent = RespondentType(rawValue: respondent_type ?? "org") ?? .org

        let metadata = Notation.Metadata(
            code: code,
            title: title,
            description: description,
            respondentType: respondent
        )

        let document: Notation.Document?
        if document_url != nil || document_type != nil || document_mappings != nil {
            let typeString = document_type ?? "pdf"
            guard let docType = DocumentType(rawValue: typeString) else {
                throw NotationError.invalidValue(field: "document_type", reason: "Unsupported value '" + typeString + "'")
            }
            let url = document_url.flatMap(URL.init(string:))
            let mappings = document_mappings?.reduce(into: [String: DocumentMapping]()) { result, pair in
                result[pair.key] = pair.value.toModel(field: pair.key)
            } ?? [:]
            document = Notation.Document(url: url, type: docType, mappings: mappings)
        } else {
            document = nil
        }

        let flowMachine = try StateMachineBuilder(rawStates: flow).build()
        let alignmentMachine = try alignment.map { try StateMachineBuilder(rawStates: $0).build() }

        return Notation(
            metadata: metadata,
            document: document,
            flow: flowMachine,
            alignment: alignmentMachine
        )
    }
}

private struct RawDocumentMapping: Decodable {
    let page: Int?
    let upper_left: [Double]?
    let lower_left: [Double]?
    let upper_right: [Double]?
    let lower_right: [Double]?

    func toModel(field: String) -> DocumentMapping {
        let quad: DocumentMapping.Quad?
        if let upperLeft = upper_left,
           let lowerLeft = lower_left,
           let upperRight = upper_right,
           let lowerRight = lower_right,
           upperLeft.count == 2,
           lowerLeft.count == 2,
           upperRight.count == 2,
           lowerRight.count == 2 {
            quad = DocumentMapping.Quad(
                upperLeft: .init(x: upperLeft[0], y: upperLeft[1]),
                lowerLeft: .init(x: lowerLeft[0], y: lowerLeft[1]),
                upperRight: .init(x: upperRight[0], y: upperRight[1]),
                lowerRight: .init(x: lowerRight[0], y: lowerRight[1])
            )
        } else {
            quad = nil
        }

        return DocumentMapping(field: field, page: page, quad: quad)
    }
}

// MARK: - State Machine Builder

private struct StateMachineBuilder {
    let rawStates: [String: [String: String]]

    func build() throws -> StateMachine {
        guard let beginTransitions = rawStates["BEGIN"] else {
            throw NotationError.missingField("flow.BEGIN")
        }

        let startDestination = try destination(from: beginTransitions)

        var nodes: [StateMachine.StateID: StateMachine.Node] = [:]

        for (rawState, transitionMap) in rawStates where rawState != "BEGIN" {
            guard rawState != "END" else { continue }
            let stateID = StateMachine.StateID(rawValue: rawState)
            if nodes[stateID] != nil {
                throw NotationError.duplicateState(rawState)
            }

            let question = QuestionReferenceParser.parse(raw: rawState)
            let transitions = try transitionMap.map { rawCondition, rawDestination -> StateMachine.Transition in
                let condition: StateMachine.Condition
                if rawCondition == "_" {
                    condition = .any
                } else {
                    condition = .choice(rawCondition)
                }

                let destination = try parseDestination(rawDestination)
                return StateMachine.Transition(condition: condition, destination: destination)
            }

            nodes[stateID] = StateMachine.Node(id: stateID, question: question, transitions: transitions)
        }

        return StateMachine(
            start: .init(destination: startDestination),
            nodes: nodes
        )
    }

    private func destination(from transitionMap: [String: String]) throws -> StateMachine.Destination {
        guard transitionMap.count == 1, let only = transitionMap.first else {
            throw NotationError.invalidValue(field: "BEGIN", reason: "Must contain exactly one transition")
        }
        return try parseDestination(only.value)
    }

    private func parseDestination(_ raw: String) throws -> StateMachine.Destination {
        if raw == "END" {
            return .end
        }

        let stateID = StateMachine.StateID(rawValue: raw)
        if rawStates[stateID.rawValue] == nil && raw != "END" {
            throw NotationError.unknownStateReference(raw)
        }

        return .state(stateID)
    }
}

// MARK: - Question Reference Parsing

private enum QuestionReferenceParser {
    static func parse(raw: String) -> QuestionReference {
        let parts = raw.split(separator: "__").map(String.init)
        guard let first = parts.first else {
            return QuestionReference(code: raw, contextTokens: [])
        }

        if parts.count > 1 {
            return QuestionReference(code: first, contextTokens: Array(parts.dropFirst()))
        } else {
            return QuestionReference(code: first, contextTokens: [])
        }
    }
}
