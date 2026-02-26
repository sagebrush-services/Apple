import Dali
import Foundation
import NotationEngine

actor DemoBackend {
    static let shared = DemoBackend()

    private struct DemoNotationBundle {
        let rawYAML: String
        let notation: Notation
        let summary: NotationSummaryDTO
        let questionDefinitions: [String: QuestionDefinitionDTO]
    }

    private struct DemoFlowRecord {
        var id: UUID
        var flowInstance: NotationEngine.FlowInstance
        var history: [FlowInstanceResponseDTO.StepHistoryDTO]
        var updatedAt: Date
    }

    private var account = AccountSummaryDTO(
        id: 1,
        email: "demo@sagebrush.services",
        name: "Demo Founder"
    )

    private var mailboxes: [MailboxSummaryDTO] = [
        MailboxSummaryDTO(
            id: 101,
            mailboxNumber: 214,
            officeName: "Las Vegas Main Office",
            officeAddress: "9205 W Russell Rd, Las Vegas, NV 89148",
            forwardingEmail: "ops@sagebrush.services",
            activatedAt: Date().addingTimeInterval(-60 * 60 * 24 * 28)
        ),
        MailboxSummaryDTO(
            id: 102,
            mailboxNumber: 332,
            officeName: "Reno Office",
            officeAddress: "50 W Liberty St, Reno, NV 89501",
            forwardingEmail: "mailroom@sagebrush.services",
            activatedAt: Date().addingTimeInterval(-60 * 60 * 24 * 14)
        ),
    ]

    private var notationsByCode: [String: DemoNotationBundle] = [:]
    private var formationInstances: [UUID: DemoFlowRecord] = [:]
    private var questions: [Question] = []
    private var people: [Person] = []
    private var nextQuestionID: Int32 = 1000
    private var hasSeeded = false

    init() {}

    // MARK: - Customer API

    func fetchDashboardSnapshot() -> DashboardSnapshotDTO {
        ensureSeeded()
        let all = formationInstances.values.map { buildFormationSummary(from: $0) }
        let active = all.filter { !$0.isCompleted }
        let completed = all.filter(\.isCompleted)
        let quickStart = notationsByCode.values.map {
            QuickStartNotationDTO(code: $0.summary.code, title: $0.summary.title, description: $0.summary.description)
        }
        return DashboardSnapshotDTO(
            person: account,
            activeFormations: active,
            completedFormations: completed,
            quickStartNotations: quickStart.sorted { $0.title < $1.title },
            pendingTaskCount: active.count,
            assignedMailboxes: mailboxes
        )
    }

    func fetchAccountSummary() -> AccountSummaryDTO {
        ensureSeeded()
        return account
    }

    func updateAccountName(_ name: String) -> AccountSummaryDTO {
        ensureSeeded()
        account = AccountSummaryDTO(id: account.id, email: account.email, name: name)
        return account
    }

    func fetchMailboxes() -> [MailboxSummaryDTO] {
        ensureSeeded()
        return mailboxes
    }

    // MARK: - Formations API

    func fetchNotationSummaries() -> [NotationSummaryDTO] {
        ensureSeeded()
        return notationsByCode.values.map(\.summary).sorted { $0.title < $1.title }
    }

    func fetchNotationYAML(code: String) throws -> String {
        ensureSeeded()
        guard let bundle = notationsByCode[code] else {
            throw DemoBackendError.notFound("Notation '\(code)' not found")
        }
        return bundle.rawYAML
    }

    func fetchQuestionDefinitions(codes: [String]) -> [QuestionDefinitionDTO] {
        ensureSeeded()
        let allDefinitions = Dictionary(uniqueKeysWithValues: notationsByCode.values.flatMap { bundle in
            bundle.questionDefinitions.map { ($0.key, $0.value) }
        })

        return codes.compactMap { code in
            if let definition = allDefinitions[code] {
                return definition
            }
            return QuestionDefinitionDTO(
                code: code,
                prompt: "Provide \(code.replacingOccurrences(of: "_", with: " "))",
                helpText: "Demo fallback question",
                type: .string,
                choices: []
            )
        }
    }

    func createFormationInstance(
        notationCode: String,
        payload: CreateFormationInstanceRequest
    ) throws -> FlowInstanceResponseDTO {
        ensureSeeded()
        guard let bundle = notationsByCode[notationCode] else {
            throw DemoBackendError.notFound("Notation '\(notationCode)' not found")
        }

        let kind = payload.kind ?? .client
        let runtimeKind: NotationEngine.FlowInstance.FlowKind = (kind == .alignment) ? .alignment : .client

        var flow = NotationEngine.FlowInstance(notation: bundle.notation, kind: runtimeKind)
        let firstState = try flow.start()
        var pendingState: StateMachine.StateID? = firstState
        var history: [FlowInstanceResponseDTO.StepHistoryDTO] = []

        while let stateID = pendingState,
            let implicit = implicitAnswer(for: flow, stateID: stateID)
        {
            guard let node = machine(for: flow).nodes[stateID] else {
                throw DemoBackendError.invalidState("Unknown state '\(stateID.rawValue)' while applying implicit answer")
            }

            pendingState = try flow.submitAnswer(implicit)
            history.append(
                FlowInstanceResponseDTO.StepHistoryDTO(
                    stateID: stateID.rawValue,
                    questionCode: node.question.code,
                    answeredAt: Date(),
                    actorRole: "system"
                )
            )
        }

        let record = DemoFlowRecord(
            id: UUID(),
            flowInstance: flow,
            history: history,
            updatedAt: Date()
        )
        formationInstances[record.id] = record
        return buildInstanceResponse(from: record)
    }

    func fetchFormationInstances() -> [FlowInstanceResponseDTO] {
        ensureSeeded()
        return formationInstances.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .map { buildInstanceResponse(from: $0) }
    }

    func fetchFormationInstance(id: UUID) throws -> FlowInstanceResponseDTO {
        ensureSeeded()
        guard let record = formationInstances[id] else {
            throw DemoBackendError.notFound("Formation '\(id)' not found")
        }
        return buildInstanceResponse(from: record)
    }

    func submitFormationStep(
        instanceID: UUID,
        request: SubmitFormationStepRequest
    ) throws -> FlowInstanceResponseDTO {
        ensureSeeded()
        guard var record = formationInstances[instanceID] else {
            throw DemoBackendError.notFound("Formation '\(instanceID)' not found")
        }

        guard let currentState = record.flowInstance.currentState else {
            throw DemoBackendError.invalidState("Formation has no active state")
        }

        let machine = machine(for: record.flowInstance)
        guard let node = machine.nodes[currentState] else {
            throw DemoBackendError.invalidState("Unknown current state '\(currentState.rawValue)'")
        }

        let answer = try self.convertAnswerPayload(request.answer)
        _ = try record.flowInstance.submitAnswer(answer)

        record.history.append(
            FlowInstanceResponseDTO.StepHistoryDTO(
                stateID: currentState.rawValue,
                questionCode: node.question.code,
                answeredAt: Date(),
                actorRole: request.actorRole ?? "client"
            )
        )
        record.updatedAt = Date()

        formationInstances[instanceID] = record
        return buildInstanceResponse(from: record)
    }

    // MARK: - Admin API

    func fetchPeople() -> [Person] {
        ensureSeeded()
        return people
    }

    func fetchQuestions() -> [Question] {
        ensureSeeded()
        return questions
    }

    func createQuestion(_ question: Question) -> Question {
        ensureSeeded()
        nextQuestionID += 1
        question.id = nextQuestionID
        question.insertedAt = Date()
        question.updatedAt = Date()
        questions.append(question)
        return question
    }

    func updateQuestion(_ question: Question) throws -> Question {
        ensureSeeded()
        guard let id = question.id, let index = questions.firstIndex(where: { $0.id == id }) else {
            throw DemoBackendError.notFound("Question not found")
        }
        question.updatedAt = Date()
        questions[index] = question
        return question
    }

    func deleteQuestion(id: Int32) throws {
        ensureSeeded()
        guard let index = questions.firstIndex(where: { $0.id == id }) else {
            throw DemoBackendError.notFound("Question not found")
        }
        questions.remove(at: index)
    }

    private func ensureSeeded() {
        if hasSeeded {
            return
        }
        loadSeedData()
        hasSeeded = true
    }

    // MARK: - Seed Data

    private func loadSeedData() {
        loadPeople()

        let llcNotationYAML = """
        ---
        code: new_llc_registration
        title: Nevada LLC Registration
        description: Guided filing flow for a new Nevada LLC.
        respondent_type: org
        flow:
          BEGIN:
            _: annual_or_amended
          annual_or_amended:
            original: entity_name__new_llc
            amended: org__existing_entity
          entity_name__new_llc:
            _: registered_agent
          org__existing_entity:
            _: registered_agent
          registered_agent:
            _: END
        alignment:
          BEGIN:
            _: staff_review
          staff_review:
            _: signature__for_registered_agent
          signature__for_registered_agent:
            _: filed_with_sos
          filed_with_sos:
            _: END
        """

        let llcQuestions: [QuestionDefinitionDTO] = [
            QuestionDefinitionDTO(
                code: "annual_or_amended",
                prompt: "Is this an original filing or an amendment?",
                helpText: "Choose the path that matches your current filing.",
                type: .radio,
                choices: [
                    .init(value: "original", label: "Original filing"),
                    .init(value: "amended", label: "Amendment"),
                ]
            ),
            QuestionDefinitionDTO(
                code: "entity_name",
                prompt: "What is the legal name for {{for_label}}?",
                helpText: "Use the exact name you want on the state filing.",
                type: .string,
                choices: []
            ),
            QuestionDefinitionDTO(
                code: "org",
                prompt: "Which existing entity is this amendment for?",
                helpText: "Type the entity name to continue.",
                type: .org,
                choices: []
            ),
            QuestionDefinitionDTO(
                code: "registered_agent",
                prompt: "Who should be the registered agent for {{for_label}}?",
                helpText: "You can use Neon Law or provide a custom agent.",
                type: .registeredAgent,
                choices: []
            ),
            QuestionDefinitionDTO(
                code: "staff_review",
                prompt: "Staff review notes",
                helpText: "Internal handoff marker.",
                type: .text,
                choices: []
            ),
            QuestionDefinitionDTO(
                code: "signature",
                prompt: "Collect signature for {{for_label}}",
                helpText: "Internal handoff marker.",
                type: .signature,
                choices: []
            ),
            QuestionDefinitionDTO(
                code: "filed_with_sos",
                prompt: "Filed with Secretary of State?",
                helpText: "Internal completion marker.",
                type: .yesNo,
                choices: []
            ),
        ]

        loadNotationBundle(yaml: llcNotationYAML, questionDefinitions: llcQuestions)
        syncQuestionsFromNotationDefinitions()
        seedFormations()
    }

    private func loadNotationBundle(yaml: String, questionDefinitions: [QuestionDefinitionDTO]) {
        do {
            let notation = try NotationParser.parse(yaml: yaml)
            let definitionMap = Dictionary(uniqueKeysWithValues: questionDefinitions.map { ($0.code, $0) })
            let summary = NotationSummaryDTO(
                code: notation.code,
                title: notation.metadata.title,
                description: notation.metadata.description,
                respondentType: notation.metadata.respondentType,
                flowStateCount: notation.flow.nodes.count,
                alignmentStateCount: notation.alignment?.nodes.count ?? 0
            )
            notationsByCode[notation.code] = DemoNotationBundle(
                rawYAML: yaml,
                notation: notation,
                summary: summary,
                questionDefinitions: definitionMap
            )
        } catch {
            assertionFailure("Failed to parse demo notation: \(error)")
        }
    }

    private func syncQuestionsFromNotationDefinitions() {
        var seededQuestions: [Question] = []
        var id: Int32 = 200

        for bundle in notationsByCode.values {
            for definition in bundle.questionDefinitions.values.sorted(by: { $0.code < $1.code }) {
                let question = Question(
                    prompt: definition.prompt,
                    questionType: definition.type,
                    code: definition.code,
                    helpText: definition.helpText,
                    choices: Dictionary(
                        uniqueKeysWithValues: definition.choices.map { ($0.value, $0.label) }
                    )
                )
                question.id = id
                question.insertedAt = Date().addingTimeInterval(-60 * 60 * 24 * 45)
                question.updatedAt = Date().addingTimeInterval(-60 * 60 * 24 * 7)
                seededQuestions.append(question)
                id += 1
            }
        }

        questions = seededQuestions.sorted { $0.code < $1.code }
        nextQuestionID = id
    }

    private func loadPeople() {
        func makePerson(id: Int32, name: String, email: String, joinedDaysAgo: Double) -> Person {
            let person = Person()
            person.id = id
            person.name = name
            person.email = email
            person.insertedAt = Date().addingTimeInterval(-60 * 60 * 24 * joinedDaysAgo)
            person.updatedAt = Date().addingTimeInterval(-60 * 60 * 24 * 2)
            return person
        }

        people = [
            makePerson(id: 1, name: "Demo Founder", email: "demo@sagebrush.services", joinedDaysAgo: 120),
            makePerson(id: 2, name: "Alex Counsel", email: "alex@sagebrush.services", joinedDaysAgo: 90),
            makePerson(id: 3, name: "Jordan Operator", email: "ops@sagebrush.services", joinedDaysAgo: 45),
        ]
    }

    private func seedFormations() {
        guard let bundle = notationsByCode["new_llc_registration"] else { return }

        // Active sample
        do {
            var activeFlow = NotationEngine.FlowInstance(notation: bundle.notation, kind: .client)
            _ = try activeFlow.start()
            _ = try activeFlow.submitAnswer(.choice("original"))
            let activeID = UUID()
            formationInstances[activeID] = DemoFlowRecord(
                id: activeID,
                flowInstance: activeFlow,
                history: [
                    .init(
                        stateID: "annual_or_amended",
                        questionCode: "annual_or_amended",
                        answeredAt: Date().addingTimeInterval(-60 * 60 * 12),
                        actorRole: "client"
                    )
                ],
                updatedAt: Date().addingTimeInterval(-60 * 60 * 12)
            )
        } catch {
            assertionFailure("Failed to seed active formation: \(error)")
        }

        // Completed sample
        do {
            var completedFlow = NotationEngine.FlowInstance(notation: bundle.notation, kind: .client)
            _ = try completedFlow.start()
            _ = try completedFlow.submitAnswer(.choice("original"))
            _ = try completedFlow.submitAnswer(.string("Sagebrush Demo LLC"))
            _ = try completedFlow.submitAnswer(
                .metadata([
                    "agent_type": "neon_law",
                    "agent_name": "Neon Law",
                    "agent_email": "support@sagebrush.services",
                ])
            )

            let completedID = UUID()
            formationInstances[completedID] = DemoFlowRecord(
                id: completedID,
                flowInstance: completedFlow,
                history: [
                    .init(
                        stateID: "annual_or_amended",
                        questionCode: "annual_or_amended",
                        answeredAt: Date().addingTimeInterval(-60 * 60 * 24 * 4),
                        actorRole: "client"
                    ),
                    .init(
                        stateID: "entity_name__new_llc",
                        questionCode: "entity_name",
                        answeredAt: Date().addingTimeInterval(-60 * 60 * 24 * 4 + 120),
                        actorRole: "client"
                    ),
                    .init(
                        stateID: "registered_agent",
                        questionCode: "registered_agent",
                        answeredAt: Date().addingTimeInterval(-60 * 60 * 24 * 4 + 240),
                        actorRole: "client"
                    ),
                ],
                updatedAt: Date().addingTimeInterval(-60 * 60 * 24 * 4 + 240)
            )
        } catch {
            assertionFailure("Failed to seed completed formation: \(error)")
        }
    }

    // MARK: - Builders

    private func buildFormationSummary(from record: DemoFlowRecord) -> FormationSummaryDTO {
        let notation = record.flowInstance.notation
        return FormationSummaryDTO(
            id: record.id,
            notationCode: notation.code,
            title: notation.metadata.title,
            status: record.flowInstance.completed ? "completed" : "active",
            stageLabel: record.flowInstance.currentState?.rawValue ?? "completed",
            progressPercent: buildProgressPercent(for: record),
            isCompleted: record.flowInstance.completed,
            nextPrompt: buildCurrentPrompt(for: record),
            updatedAt: record.updatedAt
        )
    }

    private func buildInstanceResponse(from record: DemoFlowRecord) -> FlowInstanceResponseDTO {
        let kind: FlowInstanceResponseDTO.FlowInstanceKind =
            (record.flowInstance.kind == .alignment) ? .alignment : .client
        let status: FlowInstanceResponseDTO.FlowInstanceStatus =
            record.flowInstance.completed ? .completed : .active
        let currentState = record.flowInstance.currentState?.rawValue
        let progressStage = currentState ?? "completed"

        return FlowInstanceResponseDTO(
            id: record.id,
            notationCode: record.flowInstance.notation.code,
            status: status,
            kind: kind,
            currentState: currentState,
            progressStage: progressStage,
            progressPercent: buildProgressPercent(for: record),
            isFlowComplete: record.flowInstance.completed,
            isFormationComplete: record.flowInstance.completed,
            isCompleted: record.flowInstance.completed,
            currentStep: buildCurrentStateDescriptor(for: record),
            history: record.history
        )
    }

    private func buildCurrentPrompt(for record: DemoFlowRecord) -> String? {
        guard let descriptor = buildCurrentStateDescriptor(for: record) else {
            return nil
        }
        return descriptor.prompt
    }

    private func buildCurrentStateDescriptor(for record: DemoFlowRecord) -> StateDescriptorDTO? {
        guard let stateID = record.flowInstance.currentState else { return nil }
        let machine = machine(for: record.flowInstance)
        guard let node = machine.nodes[stateID] else { return nil }

        let definition = questionDefinition(for: node.question.code)
        let descriptor = QuestionComponentFactory.makeDescriptor(
            reference: node.question,
            definition: definition.toDefinition()
        )

        return StateDescriptorDTO(
            id: stateID.rawValue,
            questionCode: node.question.code,
            contextTokens: node.question.contextTokens,
            prompt: descriptor.displayPrompt,
            helpText: descriptor.displayHelp,
            component: componentMetadata(from: descriptor.component)
        )
    }

    private func componentMetadata(
        from component: QuestionStepDescriptor.Component
    ) -> ComponentMetadataDTO {
        switch component {
        case .radio(let choices):
            return ComponentMetadataDTO(
                kind: "radio",
                allowsMultipleSelection: false,
                choices: choices.map { .init(value: $0.value, label: $0.label) }
            )
        case .picker(let choices):
            return ComponentMetadataDTO(
                kind: "select",
                allowsMultipleSelection: false,
                choices: choices.map { .init(value: $0.value, label: $0.label) }
            )
        case .multiSelect(let choices):
            return ComponentMetadataDTO(
                kind: "multi_select",
                allowsMultipleSelection: true,
                choices: choices.map { .init(value: $0.value, label: $0.label) }
            )
        case .singleLineText:
            return ComponentMetadataDTO(kind: "string", allowsMultipleSelection: false, choices: nil)
        case .multiLineText:
            return ComponentMetadataDTO(kind: "text", allowsMultipleSelection: false, choices: nil)
        case .toggle:
            return ComponentMetadataDTO(kind: "yes_no", allowsMultipleSelection: false, choices: nil)
        case .date:
            return ComponentMetadataDTO(kind: "date", allowsMultipleSelection: false, choices: nil)
        case .dateTime:
            return ComponentMetadataDTO(kind: "datetime", allowsMultipleSelection: false, choices: nil)
        case .registeredAgent:
            return ComponentMetadataDTO(kind: "registered_agent", allowsMultipleSelection: false, choices: nil)
        case .organizationLookup:
            return ComponentMetadataDTO(kind: "org", allowsMultipleSelection: false, choices: nil)
        case .integer:
            return ComponentMetadataDTO(kind: "number", allowsMultipleSelection: false, choices: nil)
        case .decimal:
            return ComponentMetadataDTO(kind: "number", allowsMultipleSelection: false, choices: nil)
        case .secret:
            return ComponentMetadataDTO(kind: "secret", allowsMultipleSelection: false, choices: nil)
        case .phone:
            return ComponentMetadataDTO(kind: "phone", allowsMultipleSelection: false, choices: nil)
        case .email:
            return ComponentMetadataDTO(kind: "email", allowsMultipleSelection: false, choices: nil)
        case .ssn:
            return ComponentMetadataDTO(kind: "ssn", allowsMultipleSelection: false, choices: nil)
        case .ein:
            return ComponentMetadataDTO(kind: "ein", allowsMultipleSelection: false, choices: nil)
        case .fileUpload:
            return ComponentMetadataDTO(kind: "file", allowsMultipleSelection: false, choices: nil)
        case .personLookup:
            return ComponentMetadataDTO(kind: "person", allowsMultipleSelection: false, choices: nil)
        case .addressEntry:
            return ComponentMetadataDTO(kind: "address", allowsMultipleSelection: false, choices: nil)
        case .signatureRequest:
            return ComponentMetadataDTO(kind: "signature", allowsMultipleSelection: false, choices: nil)
        case .notarizationRequest:
            return ComponentMetadataDTO(kind: "notarization", allowsMultipleSelection: false, choices: nil)
        case .documentUpload:
            return ComponentMetadataDTO(kind: "document", allowsMultipleSelection: false, choices: nil)
        case .issuanceLookup:
            return ComponentMetadataDTO(kind: "issuance", allowsMultipleSelection: false, choices: nil)
        case .mailboxSelect:
            return ComponentMetadataDTO(kind: "mailbox", allowsMultipleSelection: false, choices: nil)
        }
    }

    private func buildProgressPercent(for record: DemoFlowRecord) -> Double {
        if record.flowInstance.completed {
            return 1.0
        }
        let total = max(1, machine(for: record.flowInstance).nodes.count)
        return min(1.0, Double(record.history.count) / Double(total))
    }

    private func machine(for flowInstance: NotationEngine.FlowInstance) -> StateMachine {
        switch flowInstance.kind {
        case .client:
            return flowInstance.notation.flow
        case .alignment:
            return flowInstance.notation.alignment ?? flowInstance.notation.flow
        }
    }

    private func implicitAnswer(
        for flowInstance: NotationEngine.FlowInstance,
        stateID: StateMachine.StateID
    ) -> NotationEngine.FlowInstance.AnswerValue? {
        guard flowInstance.kind == .client else { return nil }
        guard flowInstance.notation.code == "new_llc_registration" else { return nil }
        guard let node = flowInstance.notation.flow.nodes[stateID] else { return nil }
        guard node.question.code == "annual_or_amended" else { return nil }
        return .choice("original")
    }

    private func questionDefinition(for code: String) -> QuestionDefinitionDTO {
        for bundle in notationsByCode.values {
            if let definition = bundle.questionDefinitions[code] {
                return definition
            }
        }

        return QuestionDefinitionDTO(
            code: code,
            prompt: code.replacingOccurrences(of: "_", with: " ").capitalized,
            helpText: nil,
            type: .string,
            choices: []
        )
    }

    private func convertAnswerPayload(
        _ payload: SubmitFormationStepRequest.AnswerPayload
    ) throws -> NotationEngine.FlowInstance.AnswerValue {
        switch payload.type {
        case "string":
            return .string(payload.stringValue ?? "")
        case "choice":
            return .choice(payload.choiceValue ?? "")
        case "multichoice":
            return .multiChoice(payload.multiChoiceValue ?? [])
        case "metadata":
            return .metadata(payload.metadata ?? [:])
        case "payload":
            return .payload(
                .init(
                    algorithm: payload.payloadAlgorithm ?? "sha256",
                    value: payload.payloadValue ?? ""
                )
            )
        default:
            throw DemoBackendError.invalidState("Unsupported answer payload '\(payload.type)'")
        }
    }
}

enum DemoBackendError: LocalizedError {
    case notFound(String)
    case invalidState(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let message):
            return message
        case .invalidState(let message):
            return message
        }
    }
}
