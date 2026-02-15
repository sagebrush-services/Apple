import Foundation
import NotationEngine

extension Question {
    public func toNotationDefinition() -> QuestionDefinition {
        let choices = (choices ?? [:])
            .sorted { $0.key < $1.key }
            .map { QuestionDefinition.Choice(value: $0.key, label: $0.value) }
        return QuestionDefinition(
            code: code,
            type: questionType,
            prompt: prompt,
            helpText: helpText,
            choices: choices
        )
    }
}
