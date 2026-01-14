import Foundation
import NotationEngine

@MainActor
final class FormationStore: ObservableObject {
    static let shared = FormationStore()

    @Published private(set) var notations: [NotationSummaryDTO] = []
    @Published private(set) var instances: [FlowInstanceResponseDTO] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var parsedNotations: [String: ParsedNotation] = [:]
    private let apiClient = APIClient.shared
#if os(iOS) && canImport(ActivityKit)
    private let activityManager = FormationActivityManager.shared
#endif

    private struct ParsedNotation {
        let notation: Notation
        let questions: [String: QuestionDefinition]
    }

    private init() {}

    // MARK: - Notations

    func refreshNotations() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let summaries = try await apiClient.fetchNotationSummaries()
            notations = summaries.sorted { $0.title < $1.title }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ensureNotationLoaded(code: String) async throws {
        if parsedNotations[code] != nil { return }

        let yaml = try await apiClient.fetchNotationYAML(code: code)
        let notation = try NotationParser.parse(yaml: yaml)

        let codes = Array(notation.allQuestionCodes)
        let definitionsDTO = try await apiClient.fetchQuestionDefinitions(codes: codes)
        let definitions = Dictionary(uniqueKeysWithValues: definitionsDTO.map { ($0.code, $0.toDefinition()) })

        parsedNotations[code] = ParsedNotation(notation: notation, questions: definitions)
    }

    // MARK: - Instances

    func refreshInstances() async {
        do {
            let list = try await apiClient.fetchFormationInstances()
            instances = list.sorted { $0.id.uuidString > $1.id.uuidString }

            for instance in list {
                try await ensureNotationLoaded(code: instance.notationCode)
#if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            activityManager.updateActivity(for: instance, notation: parsedNotations[instance.notationCode]?.notation)
        }
#endif
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createInstance(for notation: NotationSummaryDTO) async throws -> FlowInstanceResponseDTO {
        try await ensureNotationLoaded(code: notation.code)

        let response = try await apiClient.createFormationInstance(
            notationCode: notation.code,
            payload: CreateFormationInstanceRequest()
        )

        instances.insert(response, at: 0)
#if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            activityManager.startActivity(for: response, notation: parsedNotations[notation.code]?.notation)
        }
#endif
        return response
    }

    func loadInstance(id: UUID) async throws -> FlowInstanceResponseDTO {
        let response = try await apiClient.fetchFormationInstance(id: id)
        try await ensureNotationLoaded(code: response.notationCode)
        updateInstanceInStore(response)
#if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            activityManager.updateActivity(for: response, notation: parsedNotations[response.notationCode]?.notation)
        }
#endif
        return response
    }

    func submitAnswer(
        _ answer: NotationEngine.FlowInstance.AnswerValue,
        for instance: FlowInstanceResponseDTO
    ) async throws -> FlowInstanceResponseDTO {
        let request = SubmitFormationStepRequest(
            stateID: instance.currentState ?? "",
            answer: .from(answer: answer),
            actorRole: "client"
        )

        let updated = try await apiClient.submitFormationStep(
            instanceID: instance.id,
            request: request
        )

        updateInstanceInStore(updated)
#if os(iOS) && canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            activityManager.updateActivity(for: updated, notation: parsedNotations[updated.notationCode]?.notation)
        }
#endif
        return updated
    }

    func descriptor(for instance: FlowInstanceResponseDTO) -> QuestionStepDescriptor? {
        guard let stateID = instance.currentState,
              let parsed = parsedNotations[instance.notationCode]
        else {
            return nil
        }

        let stateIdentifier = StateMachine.StateID(rawValue: stateID)
        let machine: StateMachine

        if instance.kind == .alignment, let alignment = parsed.notation.alignment, alignment.nodes[stateIdentifier] != nil {
            machine = alignment
        } else {
            machine = parsed.notation.flow
        }

        guard let node = machine.nodes[stateIdentifier],
              let definition = parsed.questions[node.question.code]
        else {
            return nil
        }

        return QuestionComponentFactory.makeDescriptor(reference: node.question, definition: definition)
    }

    func notation(for code: String) -> Notation? {
        parsedNotations[code]?.notation
    }

    // MARK: - Private Helpers

    private func updateInstanceInStore(_ instance: FlowInstanceResponseDTO) {
        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            instances[index] = instance
        } else {
            instances.insert(instance, at: 0)
        }
    }
}

private extension Notation {
    var allQuestionCodes: Set<String> {
        var codes = Set(flow.nodes.values.map { $0.question.code })
        if let alignment {
            codes.formUnion(alignment.nodes.values.map { $0.question.code })
        }
        return codes
    }
}
