import Foundation

public enum FlowRuntimeError: Error, CustomStringConvertible {
    case alreadyCompleted
    case notStarted
    case invalidState(StateMachine.StateID)
    case noMatchingTransition(StateMachine.StateID)

    public var description: String {
        switch self {
        case .alreadyCompleted:
            return "Flow has already been completed"
        case .notStarted:
            return "Flow has not been started"
        case .invalidState(let state):
            return "Invalid state referenced: \(state.rawValue)"
        case .noMatchingTransition(let state):
            return "No matching transition found for state \(state.rawValue)"
        }
    }
}

public extension FlowInstance {
    mutating func start() throws -> StateMachine.StateID {
        guard !completed else { throw FlowRuntimeError.alreadyCompleted }

        switch machine.destinationForStart(kind: kind) {
        case .state(let state):
            currentState = state
            return state
        case .end:
            completed = true
            currentState = nil
            throw FlowRuntimeError.noMatchingTransition(StateMachine.StateID(rawValue: "BEGIN"))
        }
    }

    mutating func submitAnswer(
        _ value: AnswerValue,
        timestamp: Date = Date()
    ) throws -> StateMachine.StateID? {
        guard !completed else { throw FlowRuntimeError.alreadyCompleted }
        guard let stateID = currentState else { throw FlowRuntimeError.notStarted }
        let machine = self.machine

        guard let node = machine.nodes[stateID] else {
            throw FlowRuntimeError.invalidState(stateID)
        }

        answerLog[stateID] = AnswerRecord(value: value, timestamp: timestamp)

        // Evaluate transitions in declaration order
        let nextDestination = try resolveDestination(for: node, answer: value)

        switch nextDestination {
        case .state(let next):
            currentState = next
            return next
        case .end:
            currentState = nil
            completed = true
            return nil
        }
    }

    mutating func restart() {
        currentState = nil
        completed = false
        answerLog.removeAll()
    }

    private var machine: StateMachine {
        switch kind {
        case .client:
            return notation.flow
        case .alignment:
            return notation.alignment ?? notation.flow
        }
    }

    private func resolveDestination(
        for node: StateMachine.Node,
        answer: AnswerValue
    ) throws -> StateMachine.Destination {
        for transition in node.transitions {
            if matches(condition: transition.condition, answer: answer) {
                return transition.destination
            }
        }
        throw FlowRuntimeError.noMatchingTransition(node.id)
    }

    private func matches(
        condition: StateMachine.Condition,
        answer: AnswerValue
    ) -> Bool {
        switch condition {
        case .any:
            return true
        case .choice(let expected):
            switch answer {
            case .choice(let value):
                return value == expected
            case .string(let str):
                return str == expected
            case .multiChoice(let values):
                return values.contains(expected)
            case .payload, .metadata:
                return false
            }
        }
    }
}

private extension StateMachine {
    func destinationForStart(kind: FlowInstance.FlowKind) -> Destination {
        return start.destination
    }
}
