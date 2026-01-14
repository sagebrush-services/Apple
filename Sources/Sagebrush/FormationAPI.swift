import Foundation
import NotationEngine

// MARK: - Formation API v1.0
//
// All endpoints use the versioned API base path: /api/v1.0/formations

extension APIClient {
    func fetchNotationSummaries() async throws -> [NotationSummaryDTO] {
        try await makeAuthenticatedJSONRequest(
            method: "GET",
            endpoint: "/api/v1.0/formations/notations"
        )
    }

    func fetchNotationYAML(code: String) async throws -> String {
        try await makeAuthenticatedRequest(
            method: "GET",
            endpoint: "/api/v1.0/formations/notations/\(code)/raw"
        )
    }

    func fetchQuestionDefinitions(codes: [String]) async throws -> [QuestionDefinitionDTO] {
        guard !codes.isEmpty else { return [] }
        let joined = codes.joined(separator: ",")
        let endpoint = "/api/v1.0/formations/questions?codes=\(joined)"
        return try await makeAuthenticatedJSONRequest(method: "GET", endpoint: endpoint)
    }

    func createFormationInstance(
        notationCode: String,
        payload: CreateFormationInstanceRequest
    ) async throws -> FlowInstanceResponseDTO {
        let data = try JSONEncoder().encode(payload)
        return try await makeAuthenticatedJSONRequest(
            method: "POST",
            endpoint: "/api/v1.0/formations/notations/\(notationCode)/instances",
            body: data,
            decoder: DateDecoder.iso8601
        )
    }

    func fetchFormationInstances() async throws -> [FlowInstanceResponseDTO] {
        try await makeAuthenticatedJSONRequest(
            method: "GET",
            endpoint: "/api/v1.0/formations/instances",
            decoder: DateDecoder.iso8601
        )
    }

    func fetchFormationInstance(id: UUID) async throws -> FlowInstanceResponseDTO {
        try await makeAuthenticatedJSONRequest(
            method: "GET",
            endpoint: "/api/v1.0/formations/instances/\(id.uuidString)",
            decoder: DateDecoder.iso8601
        )
    }

    func submitFormationStep(
        instanceID: UUID,
        request: SubmitFormationStepRequest
    ) async throws -> FlowInstanceResponseDTO {
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        return try await makeAuthenticatedJSONRequest(
            method: "POST",
            endpoint: "/api/v1.0/formations/instances/\(instanceID.uuidString)/steps",
            body: data,
            decoder: DateDecoder.iso8601
        )
    }
}

// MARK: - Request DTOs

struct CreateFormationInstanceRequest: Codable {
    var respondentEntityID: Int32?
    var respondentPersonID: Int32?
    var kind: FlowInstanceResponseDTO.FlowInstanceKind?
}

struct SubmitFormationStepRequest: Codable {
    let stateID: String
    let answer: AnswerPayload
    var actorRole: String?

    struct AnswerPayload: Codable {
        let type: String
        let stringValue: String?
        let choiceValue: String?
        let multiChoiceValue: [String]?
        let metadata: [String: String]?
        let payloadAlgorithm: String?
        let payloadValue: String?

        static func from(answer: NotationEngine.FlowInstance.AnswerValue) -> AnswerPayload {
            switch answer {
            case .string(let value):
                return AnswerPayload(type: "string", stringValue: value, choiceValue: nil, multiChoiceValue: nil, metadata: nil, payloadAlgorithm: nil, payloadValue: nil)
            case .choice(let value):
                return AnswerPayload(type: "choice", stringValue: nil, choiceValue: value, multiChoiceValue: nil, metadata: nil, payloadAlgorithm: nil, payloadValue: nil)
            case .multiChoice(let values):
                return AnswerPayload(type: "multichoice", stringValue: nil, choiceValue: nil, multiChoiceValue: values, metadata: nil, payloadAlgorithm: nil, payloadValue: nil)
            case .metadata(let dictionary):
                return AnswerPayload(type: "metadata", stringValue: nil, choiceValue: nil, multiChoiceValue: nil, metadata: dictionary, payloadAlgorithm: nil, payloadValue: nil)
            case .payload(let hash):
                return AnswerPayload(type: "payload", stringValue: nil, choiceValue: nil, multiChoiceValue: nil, metadata: nil, payloadAlgorithm: hash.algorithm, payloadValue: hash.value)
            }
        }
    }
}

// MARK: - Helpers

enum DateDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
