import Foundation

/// Top-level errors surfaced by the notation engine.
public enum NotationError: Error, CustomStringConvertible {
    case invalidYAML(String)
    case missingField(String)
    case invalidValue(field: String, reason: String)
    case duplicateState(String)
    case unknownStateReference(String)
    case validationFailed([ValidationProblem])

    public var description: String {
        switch self {
        case .invalidYAML(let message):
            return "Invalid notation YAML: \(message)"
        case .missingField(let field):
            return "Required field '\(field)' is missing"
        case .invalidValue(let field, let reason):
            return "Field '\(field)' is invalid: \(reason)"
        case .duplicateState(let state):
            return "Duplicate state definition detected: \(state)"
        case .unknownStateReference(let reference):
            return "State references unknown destination '\(reference)'"
        case .validationFailed(let problems):
            let joined = problems.map { "• \($0.message)" }.joined(separator: "\n")
            return "Notation validation failed:\n\(joined)"
        }
    }

    /// Individual validation issue surfaced when analysing a notation against
    /// a question catalogue or structural requirements.
    public struct ValidationProblem: Sendable, Hashable {
        public let code: String
        public let message: String

        public init(code: String, message: String) {
            self.code = code
            self.message = message
        }
    }
}
