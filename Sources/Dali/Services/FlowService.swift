import Fluent
import Foundation
import NotationEngine

public actor FlowService {
    public enum ServiceError: Error {
        case notationNotFound(String)
        case instanceNotFound
    }

    private let database: Database
    private let notationProvider: NotationCatalogProvider

    public init(database: Database, notationProvider: NotationCatalogProvider) {
        self.database = database
        self.notationProvider = notationProvider
    }

    public func createInstance(
        notationCode: String,
        userID: Int32,
        kind: FlowInstanceRecord.Kind = .client,
        respondentEntityID: Int32? = nil,
        respondentPersonID: Int32? = nil
    ) async throws -> FlowInstanceRecord {
        print("FlowService.createInstance called with", notationCode)
        guard let notation = try await notationProvider.notation(with: notationCode) else {
            throw ServiceError.notationNotFound(notationCode)
        }

        var runtime = NotationEngine.FlowInstance(notation: notation, kind: kind == .client ? .client : .alignment)
        let firstState = try runtime.start()
        var pendingState: StateMachine.StateID? = firstState
        var implicitSteps: [(state: StateMachine.StateID, answer: NotationEngine.FlowInstance.AnswerValue)] = []

        while let state = pendingState,
              let implicitAnswer = implicitAnswer(notation: notation, stateID: state, kind: kind)
        {
            implicitSteps.append((state, implicitAnswer))
            pendingState = try runtime.submitAnswer(implicitAnswer)
        }

        let resultingState = pendingState
        let status: FlowInstanceRecord.Status = runtime.completed ? .completed : .active
        let progressStage = ProgressMapper.stage(for: notationCode, stateID: resultingState?.rawValue)
        let progressPercent = ProgressMapper.percent(for: notationCode, stateID: resultingState?.rawValue)

        let instance = FlowInstanceRecord(
            notationCode: notationCode,
            kind: kind,
            status: status,
            currentState: resultingState?.rawValue,
            progressStage: progressStage,
            progressPercent: progressPercent,
            respondentEntityID: respondentEntityID,
            respondentPersonID: respondentPersonID,
            userID: userID
        )

        if runtime.completed {
            instance.completedAt = Date()
        }

        try await instance.save(on: database)

        if !implicitSteps.isEmpty {
            let instanceID = try instance.requireID()
            for step in implicitSteps {
                let record = try FlowStepRecord(
                    instanceID: instanceID,
                    stateID: step.state.rawValue,
                    questionCode: QuestionReferenceParser.extractQuestionCode(from: step.state.rawValue),
                    contextTokens: QuestionReferenceParser.extractContext(from: step.state.rawValue),
                    answer: step.answer,
                    actorRole: .system,
                    actorUserID: nil
                )
                try await record.save(on: database)
            }
        }

        return instance
    }

    private func implicitAnswer(
        notation: Notation,
        stateID: StateMachine.StateID,
        kind: FlowInstanceRecord.Kind
    ) -> NotationEngine.FlowInstance.AnswerValue? {
        guard kind == .client else { return nil }
        guard notation.code == "new_llc_registration" else { return nil }
        guard let node = notation.flow.nodes[stateID] else { return nil }
        guard node.question.code == "annual_or_amended" else { return nil }
        return .choice("original")
    }

    public func loadInstance(id: UUID) async throws -> FlowInstanceRecord {
        print("FlowService.loadInstance", id)
        guard let instance = try await FlowInstanceRecord.find(id, on: database) else {
            throw ServiceError.instanceNotFound
        }
        return instance
    }

    public func listInstances(for userID: Int32) async throws -> [FlowInstanceRecord] {
        try await FlowInstanceRecord.query(on: database)
            .filter(\.$user.$id == userID)
            .sort(\.$createdAt, .descending)
            .with(\.$steps)
            .all()
    }

    public func advance(
        instanceID: UUID,
        stateID: String,
        answer: NotationEngine.FlowInstance.AnswerValue,
        actorRole: FlowStepRecord.ActorRole,
        actorUserID: Int32?
    ) async throws -> FlowInstanceRecord {
        guard let instance = try await FlowInstanceRecord.find(instanceID, on: database) else {
            throw ServiceError.instanceNotFound
        }

        guard let notation = try await notationProvider.notation(with: instance.notationCode) else {
            throw ServiceError.notationNotFound(instance.notationCode)
        }

        var runtime = NotationEngine.FlowInstance(notation: notation, kind: instance.kind == .client ? .client : .alignment)
        runtime.currentState = instance.currentState.map { StateMachine.StateID(rawValue: $0) }
        runtime.completed = instance.status == .completed

        let next = try runtime.submitAnswer(answer)

        let step = try FlowStepRecord(
            instanceID: instance.requireID(),
            stateID: stateID,
            questionCode: QuestionReferenceParser.extractQuestionCode(from: stateID),
            contextTokens: QuestionReferenceParser.extractContext(from: stateID),
            answer: answer,
            actorRole: actorRole,
            actorUserID: actorUserID
        )

        try await step.save(on: database)

        instance.currentState = next?.rawValue
        instance.status = runtime.completed ? .completed : .active
        if runtime.completed {
            instance.completedAt = Date()
        }
        instance.progressStage = ProgressMapper.stage(for: instance.notationCode, stateID: next?.rawValue)
        instance.progressPercent = ProgressMapper.percent(for: instance.notationCode, stateID: next?.rawValue)

        try await instance.save(on: database)

        return instance
    }
}

// MARK: - Support Types

enum QuestionReferenceParser {
    static func extractQuestionCode(from stateID: String) -> String {
        return stateID.split(separator: "__").first.map(String.init) ?? stateID
    }

    static func extractContext(from stateID: String) -> [String] {
        let parts = stateID.split(separator: "__").map(String.init)
        guard parts.count > 1 else { return [] }
        return Array(parts.dropFirst())
    }
}

enum ProgressMapper {
    static func stage(for notationCode: String, stateID: String?) -> String? {
        guard let stateID else { return "completed" }
        switch (notationCode, stateID) {
        case ("new_llc_registration", "annual_or_amended"):
            return "application-type"
        case ("new_llc_registration", "entity_name__new_llc"):
            return "entity-name"
        case ("new_llc_registration", "org__existing_entity"):
            return "entity-selection"
        case ("new_llc_registration", "org__entity"):
            return "entity-details"
        case ("new_llc_registration", "registered_agent"):
            return "registered-agent"
        default:
            return humanizeStateID(stateID)
        }
    }

    static func percent(for notationCode: String, stateID: String?) -> Double? {
        guard let stateID else { return 1.0 }
        switch (notationCode, stateID) {
        case ("new_llc_registration", "annual_or_amended"):
            return 0.2
        case ("new_llc_registration", "entity_name__new_llc"):
            return 0.4
        case ("new_llc_registration", "org__existing_entity"):
            return 0.4
        case ("new_llc_registration", "org__entity"):
            return 0.5
        case ("new_llc_registration", "registered_agent"):
            return 0.8
        default:
            return nil
        }
    }

    /// Converts a state ID like "entity_name__new_llc" to "Entity Name"
    private static func humanizeStateID(_ stateID: String) -> String {
        // Extract the question code (first part before __)
        let questionCode = stateID.split(separator: "__").first.map(String.init) ?? stateID

        // Convert underscores to spaces and title case
        return questionCode
            .split(separator: "_")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}
