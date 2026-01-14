import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DashboardOverviewView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var viewModel: DashboardViewModel
    @Binding var selectedSection: DashboardSection

    private var backgroundColor: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.snapshot == nil {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let snapshot = viewModel.snapshot {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroCard(snapshot: snapshot)
                        metricsGrid(snapshot: snapshot)
                        quickActions
                        if !snapshot.activeFormations.isEmpty {
                            formationSection(snapshot: snapshot)
                        }
                        if !snapshot.assignedMailboxes.isEmpty {
                            mailroomSection(snapshot: snapshot)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
                .background(backgroundColor)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text("We couldn’t load your dashboard")
                        .font(.headline)
                    Text(error)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button(action: { Task { await viewModel.refresh() } }) {
                        Label("Try again", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if viewModel.snapshot == nil && !viewModel.isLoading {
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private func heroCard(snapshot: DashboardSnapshotDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hello, \(greetingName(for: snapshot))")
                .font(.largeTitle)
                .bold()
            Text("You're managing \(snapshot.activeFormations.count) active formation(s) and \(snapshot.assignedMailboxes.count) Sagebrush mailbox(es).")
                .font(.callout)
                .foregroundColor(.secondary)
            if snapshot.pendingTaskCount > 0 {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(0.15))
                    .overlay(
                        HStack {
                            Image(systemName: "checkmark.seal")
                                .foregroundColor(.green)
                            Text("\(snapshot.pendingTaskCount) task\(snapshot.pendingTaskCount == 1 ? "" : "s") waiting")
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                    )
                    .frame(height: 44)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func metricsGrid(snapshot: DashboardSnapshotDTO) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                MetricCard(title: "Active", value: snapshot.activeFormations.count, footer: "Formations in progress", tint: .blue)
                MetricCard(title: "Completed", value: snapshot.completedFormations.count, footer: "Filed successfully", tint: .green)
            }
            GridRow {
                MetricCard(title: "Mailboxes", value: snapshot.assignedMailboxes.count, footer: "Assigned at Sagebrush", tint: .purple)
                MetricCard(title: "Workflows", value: snapshot.quickStartNotations.count, footer: "Ready to launch", tint: .orange)
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    ActionChip(label: "New formation", systemImage: "play.circle.fill") {
                        selectedSection = .formations
                    }
                    if authManager.isAdmin {
                        ActionChip(label: "Admin", systemImage: "gearshape.2") {
                            selectedSection = .admin
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private func formationSection(snapshot: DashboardSnapshotDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Formations", subtitle: "Keep momentum by completing outstanding steps.")
            ForEach(snapshot.activeFormations.prefix(3)) { summary in
                FormationRow(summary: summary)
            }
            Button("View all formations") {
                selectedSection = .formations
            }
            .buttonStyle(.bordered)
        }
    }

    private func mailroomSection(snapshot: DashboardSnapshotDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Mailroom", subtitle: "Monitor occupancy and forwarding preferences.")
            ForEach(snapshot.assignedMailboxes) { mailbox in
                MailboxRow(mailbox: mailbox)
            }
            Button("Manage mailroom") {
                selectedSection = .mailroom
            }
            .buttonStyle(.bordered)
        }
    }

    private func greetingName(for snapshot: DashboardSnapshotDTO) -> String {
        if let givenName = authManager.userGivenName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !givenName.isEmpty {
            return givenName
        }

        let rawName = snapshot.person.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawName.isEmpty {
            let components = rawName.components(separatedBy: .whitespaces)
            if let first = components.first, !first.isEmpty {
                return first
            }
            return rawName
        }

        let email = snapshot.person.email
        if let handle = email.split(separator: "@").first, !handle.isEmpty {
            return String(handle)
        }

        if let fallbackEmail = authManager.userEmail,
           let handle = fallbackEmail.split(separator: "@").first,
           !handle.isEmpty {
            return String(handle)
        }

        return "there"
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let footer: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(value)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(tint)
            Text(footer)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ActionChip: View {
    let label: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.accentColor.opacity(0.2))
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2)
                .bold()
            Text(subtitle)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

private struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct FormationRow: View {
    let summary: FormationSummaryDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.title)
                .font(.headline)
            if let next = summary.nextPrompt {
                Text(next)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: summary.progressPercent ?? (summary.isCompleted ? 1 : 0))
                .progressViewStyle(.linear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct MailboxRow: View {
    let mailbox: MailboxSummaryDTO

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "envelope.fill")
                .foregroundColor(.purple)
            VStack(alignment: .leading, spacing: 4) {
                Text("Mailbox #\(mailbox.mailboxNumber)")
                    .font(.headline)
                Text(mailbox.officeName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let forwarding = mailbox.forwardingEmail {
                    Text("Forwarding to \(forwarding)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
