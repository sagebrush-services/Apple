import SwiftUI

struct MailroomOverviewView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @State private var isRefreshing = false

    var body: some View {
        Group {
            if let snapshot = viewModel.snapshot {
                List {
                    Section("Assigned mailboxes") {
                        if snapshot.assignedMailboxes.isEmpty {
                            Text("You don't have any assigned mailboxes yet.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical)
                        } else {
                            ForEach(snapshot.assignedMailboxes) { mailbox in
                                MailboxCell(mailbox: mailbox)
                            }
                        }
                    }
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
            } else if viewModel.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Text("Mailroom data unavailable")
                        .font(.headline)
                    Button("Reload") {
                        Task { await viewModel.refresh() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Mailroom")
        .toolbar {
            if viewModel.isLoading {
                ProgressView()
            }
        }
        .task {
            if viewModel.snapshot == nil {
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private struct MailboxCell: View {
        let mailbox: MailboxSummaryDTO

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
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
                if let activated = mailbox.activatedAt {
                    Text("Assigned \(activated.formatted(.dateTime.month().day().year()))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
