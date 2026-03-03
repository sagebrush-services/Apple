#if os(iOS)
import SwiftUI

struct SubscriptionSuccessView: View {
    let subscription: SubscriptionDTO
    let payment: PaymentResultDTO
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Success Icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                // Success Message
                VStack(spacing: 8) {
                    Text("Subscription Activated!")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Your payment was successful")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                // Payment Details
                VStack(spacing: 16) {
                    DetailRow(
                        label: "Subscription Type",
                        value: subscription.subscriptionType.capitalized
                    )

                    DetailRow(
                        label: "Billing",
                        value: "\(subscription.displayPrice) \(subscription.displayInterval)"
                    )

                    DetailRow(
                        label: "Amount Paid",
                        value: payment.displayAmount
                    )

                    if let nextBilling = subscription.nextBillingDate {
                        DetailRow(
                            label: "Next Billing Date",
                            value: formatDate(nextBilling)
                        )
                    }

                    DetailRow(
                        label: "Status",
                        value: subscription.status.capitalized
                    )
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()

                // Done Button
                Button {
                    onDismiss()
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Success")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    SubscriptionSuccessView(
        subscription: SubscriptionDTO(
            id: UUID(),
            subscriptionType: "mailbox",
            billingInterval: "monthly",
            status: "active",
            priceCents: 4900,
            currency: "USD",
            nextBillingDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
            xeroRepeatingInvoiceId: nil,
            stripeCustomerId: nil,
            stripeSubscriptionId: nil,
            stripePriceId: nil
        ),
        payment: PaymentResultDTO(
            id: UUID(),
            status: "succeeded",
            amountCents: 4900,
            processedAt: Date()
        ),
        onDismiss: {}
    )
}
#endif
