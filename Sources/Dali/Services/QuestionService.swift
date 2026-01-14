import Fluent
import Foundation
import NotationEngine
import Vapor

/// Service layer for managing Question entities with CRUD operations.
///
/// This service provides a clean interface for Question management,
/// handling all database operations and business logic.
public actor QuestionService {
    private let database: Database

    public init(database: Database) {
        self.database = database
    }

    /// Creates a new question in the database.
    ///
    /// - Parameters:
    ///   - prompt: The question prompt text
    ///   - questionType: The type of question input
    ///   - code: Unique code identifier for the question
    ///   - helpText: Optional help text for the question
    ///   - choices: Optional dictionary of choices for select/radio questions
    /// - Returns: The created Question
    /// - Throws: Database errors or validation errors
    public func create(
        prompt: String,
        questionType: QuestionType,
        code: String,
        helpText: String? = nil,
        choices: [String: String]? = nil
    ) async throws -> Question {
        let question = Question(
            prompt: prompt,
            questionType: questionType,
            code: code,
            helpText: helpText,
            choices: choices
        )

        try await question.save(on: database)
        return question
    }

    /// Retrieves all questions from the database.
    ///
    /// - Parameter sortByCode: If true, sorts questions by code alphabetically
    /// - Returns: Array of all questions
    /// - Throws: Database errors
    public func list(sortByCode: Bool = false) async throws -> [Question] {
        let query = Question.query(on: database)

        if sortByCode {
            return try await query.sort(\.$code).all()
        }

        return try await query.all()
    }

    /// Retrieves a specific question by ID.
    ///
    /// - Parameter id: The question ID
    /// - Returns: The requested question
    /// - Throws: Not found error or database errors
    public func get(id: Int32) async throws -> Question {
        guard let question = try await Question.find(id, on: database) else {
            throw Abort(.notFound, reason: "Question with ID \(id) not found")
        }
        return question
    }

    /// Retrieves a specific question by code.
    ///
    /// - Parameter code: The unique question code
    /// - Returns: The requested question
    /// - Throws: Not found error or database errors
    public func getByCode(_ code: String) async throws -> Question {
        guard
            let question = try await Question.query(on: database)
                .filter(\.$code == code)
                .first()
        else {
            throw Abort(.notFound, reason: "Question with code '\(code)' not found")
        }
        return question
    }

    /// Updates an existing question.
    ///
    /// - Parameters:
    ///   - id: The question ID to update
    ///   - prompt: New prompt text (optional)
    ///   - questionType: New question type (optional)
    ///   - code: New code (optional)
    ///   - helpText: New help text (optional)
    ///   - choices: New choices (optional)
    /// - Returns: The updated question
    /// - Throws: Not found error or database errors
    public func update(
        id: Int32,
        prompt: String? = nil,
        questionType: QuestionType? = nil,
        code: String? = nil,
        helpText: String? = nil,
        choices: [String: String]? = nil
    ) async throws -> Question {
        guard let question = try await Question.find(id, on: database) else {
            throw Abort(.notFound, reason: "Question with ID \(id) not found")
        }

        if let prompt = prompt {
            question.prompt = prompt
        }
        if let questionType = questionType {
            question.questionType = questionType
        }
        if let code = code {
            question.code = code
        }
        if let helpText = helpText {
            question.helpText = helpText
        }
        if let choices = choices {
            question.choices = choices
        }

        try await question.save(on: database)
        return question
    }

    /// Deletes a question from the database.
    ///
    /// - Parameter id: The question ID to delete
    /// - Throws: Not found error or database errors
    public func delete(id: Int32) async throws {
        guard let question = try await Question.find(id, on: database) else {
            throw Abort(.notFound, reason: "Question with ID \(id) not found")
        }

        try await question.delete(on: database)
    }

    /// Exports all questions in YAML format matching the seed file structure.
    ///
    /// - Returns: YAML string representation of all questions
    /// - Throws: Database errors
    public func exportToYAML() async throws -> String {
        let questions = try await list(sortByCode: true)

        var yaml = "lookup_fields:\n  - code\nrecords:\n"

        for question in questions {
            yaml += "  - code: \(question.code)\n"
            yaml += "    prompt: \(question.prompt)\n"
            yaml += "    question_type: \(question.questionType.rawValue)\n"

            if let helpText = question.helpText {
                if helpText.contains("\n") {
                    yaml += "    help_text: |\n"
                    let lines = helpText.split(separator: "\n")
                    for line in lines {
                        yaml += "      \(line)\n"
                    }
                } else {
                    yaml += "    help_text: \(helpText)\n"
                }
            }

            if let choices = question.choices, !choices.isEmpty {
                yaml += "    choices:\n"
                for (key, value) in choices.sorted(by: { $0.key < $1.key }) {
                    yaml += "      \(key): \(value)\n"
                }
            }
        }

        return yaml
    }

    /// Fetches question definitions mapped by code for use in notation rendering.
    public func definitions(for codes: [String]) async throws -> [String: QuestionDefinition] {
        guard !codes.isEmpty else { return [:] }

        let questions = try await Question.query(on: database)
            .filter(\.$code ~~ codes)
            .all()

        var map: [String: QuestionDefinition] = [:]
        for question in questions {
            map[question.code] = question.toNotationDefinition()
        }
        return map
    }
}

/// Request/Response DTOs for Question endpoints

/// Request structure for creating a new question.
public struct CreateQuestionRequest: Content, Validatable {
    public let prompt: String
    public let questionType: QuestionType
    public let code: String
    public let helpText: String?
    public let choices: [String: String]?

    public init(
        prompt: String,
        questionType: QuestionType,
        code: String,
        helpText: String? = nil,
        choices: [String: String]? = nil
    ) {
        self.prompt = prompt
        self.questionType = questionType
        self.code = code
        self.helpText = helpText
        self.choices = choices
    }

    public static func validations(_ validations: inout Validations) {
        validations.add("prompt", as: String.self, is: !.empty)
        validations.add("code", as: String.self, is: !.empty)
    }
}

/// Request structure for updating an existing question.
public struct UpdateQuestionRequest: Content {
    public let prompt: String?
    public let questionType: QuestionType?
    public let code: String?
    public let helpText: String?
    public let choices: [String: String]?

    public init(
        prompt: String? = nil,
        questionType: QuestionType? = nil,
        code: String? = nil,
        helpText: String? = nil,
        choices: [String: String]? = nil
    ) {
        self.prompt = prompt
        self.questionType = questionType
        self.code = code
        self.helpText = helpText
        self.choices = choices
    }
}

/// Response structure for a question.
public struct QuestionResponse: Content {
    public let id: Int32
    public let prompt: String
    public let questionType: String
    public let code: String
    public let helpText: String?
    public let choices: [String: String]?
    public let insertedAt: Date?
    public let updatedAt: Date?

    public init(from question: Question) {
        self.id = question.id ?? 0
        self.prompt = question.prompt
        self.questionType = question.questionType.rawValue
        self.code = question.code
        self.helpText = question.helpText
        self.choices = question.choices
        self.insertedAt = question.insertedAt
        self.updatedAt = question.updatedAt
    }
}
