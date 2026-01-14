import Foundation

struct DashboardSnapshotDTO: Codable {
    let person: AccountSummaryDTO
    let activeFormations: [FormationSummaryDTO]
    let completedFormations: [FormationSummaryDTO]
    let quickStartNotations: [QuickStartNotationDTO]
    let pendingTaskCount: Int
    let assignedMailboxes: [MailboxSummaryDTO]
}

struct AccountSummaryDTO: Codable {
    let id: Int32
    let email: String
    let name: String
}

struct FormationSummaryDTO: Codable, Identifiable {
    let id: UUID
    let notationCode: String
    let title: String
    let status: String
    let stageLabel: String
    let progressPercent: Double?
    let isCompleted: Bool
    let nextPrompt: String?
    let updatedAt: Date?
}

struct QuickStartNotationDTO: Codable, Identifiable {
    let code: String
    let title: String
    let description: String?

    var id: String { code }
}

struct MailboxSummaryDTO: Codable, Identifiable {
    let id: Int32
    let mailboxNumber: Int
    let officeName: String
    let officeAddress: String
    let forwardingEmail: String?
    let activatedAt: Date?
}
