#if os(iOS)
import Foundation
#if canImport(ActivityKit)
import ActivityKit
import NotationEngine

@available(iOS 16.1, *)
struct FormationProgressAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var stage: String
        var percentComplete: Double
        var lastUpdated: Date
    }

    var instanceID: UUID
    var notationTitle: String
}

@available(iOS 16.1, *)
@MainActor
final class FormationActivityManager {
    static let shared = FormationActivityManager()

    private var activities: [UUID: Activity<FormationProgressAttributes>] = [:]

    private init() {}

    func startActivity(for instance: FlowInstanceResponseDTO, notation: Notation?) {
        guard activities[instance.id] == nil else { return }

        let attributes = FormationProgressAttributes(
            instanceID: instance.id,
            notationTitle: notation?.metadata.title ?? instance.notationCode
        )

        let state = FormationProgressAttributes.ContentState(
            stage: instance.progressStage ?? "Starting",
            percentComplete: instance.progressPercent ?? 0.0,
            lastUpdated: Date()
        )

        do {
            let activity = try Activity<FormationProgressAttributes>.request(
                attributes: attributes,
                contentState: state,
                pushType: nil
            )
            activities[instance.id] = activity
        } catch {
            print("Failed to start formation activity: \(error)")
        }
    }

    func updateActivity(for instance: FlowInstanceResponseDTO, notation: Notation?) {
        guard let activity = activities[instance.id] else {
            startActivity(for: instance, notation: notation)
            return
        }

        let state = FormationProgressAttributes.ContentState(
            stage: instance.progressStage ?? (instance.isCompleted ? "Completed" : "In Progress"),
            percentComplete: instance.progressPercent ?? (instance.isCompleted ? 1.0 : 0.0),
            lastUpdated: Date()
        )

        Task {
            await activity.update(using: state)

            if instance.isCompleted {
                await activity.end(dismissalPolicy: .immediate)
                activities.removeValue(forKey: instance.id)
            }
        }
    }

    func endActivity(for instanceID: UUID) {
        guard let activity = activities[instanceID] else { return }
        Task { await activity.end(dismissalPolicy: .immediate) }
        activities.removeValue(forKey: instanceID)
    }

    func endAll() {
        for (id, activity) in activities {
            Task { await activity.end(dismissalPolicy: .immediate) }
            activities.removeValue(forKey: id)
        }
    }
}
#endif
#endif
