import Foundation

/// Validates a parsed notation against a catalogue of known questions and
/// structural requirements.
public enum NotationValidator {
    public struct Configuration: Sendable {
        public let questions: [String: QuestionDefinition]
        public let allowImplicitEndStates: Bool

        public init(questions: [QuestionDefinition], allowImplicitEndStates: Bool = true) {
            self.questions = Dictionary(uniqueKeysWithValues: questions.map { ($0.code, $0) })
            self.allowImplicitEndStates = allowImplicitEndStates
        }

        public init(questions: [String: QuestionDefinition], allowImplicitEndStates: Bool = true) {
            self.questions = questions
            self.allowImplicitEndStates = allowImplicitEndStates
        }
    }

    public static func validate(_ notation: Notation, configuration: Configuration) throws {
        var problems: [NotationError.ValidationProblem] = []

        func validate(machine: StateMachine, context: String) {
            var visited: Set<StateMachine.StateID> = []
            var stack: [StateMachine.StateID] = []

            func walk(_ state: StateMachine.StateID) {
                guard visited.insert(state).inserted else { return }
                stack.append(state)

                guard let node = machine.nodes[state] else {
                    problems.append(
                        .init(
                            code: "missing_node",
                            message: "State \(state.rawValue) referenced in \(context) but not defined"
                        )
                    )
                    _ = stack.popLast()
                    return
                }

                // Ensure question definition exists
                if configuration.questions[node.question.code] == nil {
                    problems.append(
                        .init(
                            code: "unknown_question",
                            message:
                                "Question code '\(node.question.code)' referenced by state \(state.rawValue) is missing from catalogue"
                        )
                    )
                }

                // Validate transitions
                for transition in node.transitions {
                    switch transition.destination {
                    case .state(let next):
                        walk(next)
                    case .end:
                        break
                    }

                    // Validate choice binding when required
                    if case .choice = transition.condition,
                        let definition = configuration.questions[node.question.code],
                        definition.choices.isEmpty,
                        definition.type.requiresChoices
                    {
                        problems.append(
                            .init(
                                code: "missing_choices",
                                message: "Question '\(definition.code)' requires choices but none were provided"
                            )
                        )
                    }
                }

                _ = stack.popLast()
            }

            switch machine.start.destination {
            case .state(let initial):
                walk(initial)
            case .end:
                problems.append(.init(code: "empty_flow", message: "\(context.capitalized) cannot start at END"))
            }

            // Optional: ensure every node can reach END when implicit states are not allowed
            if !configuration.allowImplicitEndStates {
                for (stateID, node) in machine.nodes {
                    let leadsToEnd = node.transitions.contains { destination in
                        switch destination.destination {
                        case .end: return true
                        // placeholder check by recursion not necessary here
                        case .state(let next): return next == stateID
                        }
                    }
                    if !leadsToEnd {
                        problems.append(
                            .init(
                                code: "no_end",
                                message: "State \(stateID.rawValue) in \(context) does not lead to END"
                            )
                        )
                    }
                }
            }
        }

        validate(machine: notation.flow, context: "flow")
        if let alignment = notation.alignment {
            validate(machine: alignment, context: "alignment")
        }

        if !problems.isEmpty {
            throw NotationError.validationFailed(problems)
        }
    }
}
