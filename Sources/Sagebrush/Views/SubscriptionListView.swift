#if os(iOS)
import SwiftUI

struct SubscriptionListView: View {
    @StateObject private var apiClient = APIClient.shared
    @State private var subscriptions: [SubscriptionDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && subscriptions.isEmpty {
                    ProgressView("Loading subscriptions...")
                } else if subscriptions.isEmpty {
                    emptyState
                } else {
                    subscriptionList
                }
            }
            .navigationTitle("Subscriptions")
            .refreshable {
                await loadSubscriptions()
            }
            .task {
                await loadSubscriptions()
            }
            .alert(
                "Error",
                isPresented: $showingError,
                actions: {
                    Button("OK", role: .cancel) {}
                },
                message: {
                    Text(errorMessage ?? "An unknown error occurred")
                }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Active Subscriptions")
                .font(.title2)
                .fontWeight(.semibold)

            Text("You don't have any active subscriptions yet")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var subscriptionList: some View {
        List {
            ForEach(subscriptions) { subscription in
                SubscriptionCard(subscription: subscription)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
        .listStyle(.plain)
    }

    private func loadSubscriptions() async {
        isLoading = true
        errorMessage = nil

        if AppRuntimeMode.isStandaloneDemoEnabled {
            await MainActor.run {
                subscriptions = []
                isLoading = false
            }
            return
        }

        do {
            let fetchedSubscriptions = try await apiClient.fetchSubscriptions()
            await MainActor.run {
                subscriptions = fetchedSubscriptions
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                isLoading = false
            }
        }
    }
}

private struct SubscriptionCard: View {
    let subscription: SubscriptionDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.subscriptionType.capitalized)
                        .font(.headline)

                    Text(subscription.billingInterval.capitalized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                StatusBadge(status: subscription.status)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(subscription.displayPrice)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                if let nextBilling = subscription.nextBillingDate {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Next Billing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatDate(nextBilling))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status.capitalized)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }

    private var backgroundColor: Color {
        switch status.lowercased() {
        case "active":
            return Color.green.opacity(0.2)
        case "pending":
            return Color.orange.opacity(0.2)
        case "cancelled", "canceled":
            return Color.red.opacity(0.2)
        default:
            return Color.gray.opacity(0.2)
        }
    }

    private var textColor: Color {
        switch status.lowercased() {
        case "active":
            return .green
        case "pending":
            return .orange
        case "cancelled", "canceled":
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    SubscriptionListView()
}
#endif
