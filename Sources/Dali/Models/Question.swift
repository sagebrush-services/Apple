import Fluent
import Foundation
import NotationEngine
import Vapor

/// A question template used in Sagebrush Standards forms and workflows.
///
/// Questions define the structure and behavior of form fields, including
/// their input types, validation rules, and display options.
public final class Question: Model, @unchecked Sendable {
    public static let schema = "questions"

    @ID(custom: .id, generatedBy: .database)
    public var id: Int32?

    @Field(key: "prompt")
    public var prompt: String

    @Field(key: "question_type")
    public var questionType: QuestionType

    @Field(key: "code")
    public var code: String

    @Field(key: "help_text")
    public var helpText: String?

    @Field(key: "choices")
    public var choices: [String: String]?

    @Timestamp(key: "inserted_at", on: .create)
    public var insertedAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() {}

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
}
