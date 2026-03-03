#if os(iOS)
import SwiftUI
import PassKit
import StripeApplePay

struct SubscriptionView: View {
    @StateObject private var apiClient = APIClient.shared
    @Environment(\.dismiss) private var dismiss

    let subscriptionType: String
    let mailboxID: Int32?
    let flowInstanceID: UUID?

    @State private var selectedFrequency: BillingFrequency = .monthly
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var createdSubscription: SubscriptionDTO?
    @State private var paymentResult: PaymentResultDTO?

    enum BillingFrequency: String, CaseIterable {
        case monthly = "Monthly"
        case annual = "Annual"

        var displayName: String { rawValue }
        var apiValue: String { rawValue.lowercased() }
    }

    private var monthlyPrice: Int {
        switch subscriptionType.lowercased() {
        case "mailbox":
            return 4900  // $49/month
        case "formation":
            return 9900  // $99/month
        default:
            return 4900
        }
    }

    private var annualPrice: Int {
        let monthly = monthlyPrice
        let annual = monthly * 12
        let discount = Int(Double(annual) * 0.15)  // 15% discount
        return annual - discount
    }

    private var currentPrice: Int {
        selectedFrequency == .monthly ? monthlyPrice : annualPrice
    }

    private var displayPrice: String {
        let dollars = Double(currentPrice) / 100.0
        return String(format: "$%.2f", dollars)
    }

    private var savingsText: String? {
        guard selectedFrequency == .annual else { return nil }
        let monthlyCost = monthlyPrice * 12
        let savings = monthlyCost - annualPrice
        let savingsDollars = Double(savings) / 100.0
        return String(format: "Save $%.2f per year", savingsDollars)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: iconName)
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)

                        Text(title)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(subtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Frequency Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Billing Frequency")
                            .font(.headline)

                        Picker("Billing Frequency", selection: $selectedFrequency) {
                            ForEach(BillingFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                        .pickerStyle(.segmented)

                        if let savings = savingsText {
                            Text(savings)
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)

                    // Price Display
                    VStack(spacing: 8) {
                        Text(displayPrice)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.primary)

                        Text(selectedFrequency == .monthly ? "per month" : "per year")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 16)

                    // Features List
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What's Included")
                            .font(.headline)

                        ForEach(features, id: \.self) { feature in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(feature)
                                    .font(.body)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Apple Pay Button
                    if StripeAPI.deviceSupportsApplePay() {
                        Button {
                            startStripeApplePay()
                        } label: {
                            HStack {
                                Image(systemName: "applelogo")
                                Text("Subscribe with Apple Pay")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                        .padding(.horizontal)
                    } else {
                        Text("Apple Pay is not available on this device")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                    }

                    if isProcessing {
                        ProgressView("Processing...")
                            .padding()
                    }

                    Spacer()
                }
            }
            .navigationTitle("Subscribe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
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
            .sheet(isPresented: $showingSuccess) {
                if let subscription = createdSubscription, let payment = paymentResult {
                    SubscriptionSuccessView(
                        subscription: subscription,
                        payment: payment,
                        onDismiss: {
                            showingSuccess = false
                            dismiss()
                        }
                    )
                }
            }
        }
    }

    private var iconName: String {
        switch subscriptionType.lowercased() {
        case "mailbox":
            return "envelope.fill"
        case "formation":
            return "doc.text.fill"
        default:
            return "star.fill"
        }
    }

    private var title: String {
        switch subscriptionType.lowercased() {
        case "mailbox":
            return "Mailbox Service"
        case "formation":
            return "Formation Service"
        default:
            return "Subscription"
        }
    }

    private var subtitle: String {
        switch subscriptionType.lowercased() {
        case "mailbox":
            return "Professional mail handling and forwarding"
        case "formation":
            return "Business formation and compliance support"
        default:
            return "Subscribe to our service"
        }
    }

    private var features: [String] {
        switch subscriptionType.lowercased() {
        case "mailbox":
            return [
                "Physical mailing address",
                "Mail scanning and forwarding",
                "Online mail management",
                "Package handling",
                "Email notifications",
            ]
        case "formation":
            return [
                "Business entity formation",
                "Registered agent service",
                "Compliance monitoring",
                "Document management",
                "Support from experts",
            ]
        default:
            return ["Access to all features"]
        }
    }

    private func startStripeApplePay() {
        guard !isProcessing else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let publishableKeyResponse = try await apiClient.fetchStripePublishableKey()
                StripeAPI.defaultPublishableKey = publishableKeyResponse.publishableKey

                let intent = try await apiClient.createApplePayIntent(
                    type: subscriptionType,
                    frequency: selectedFrequency.apiValue,
                    mailboxID: mailboxID,
                    flowInstanceID: flowInstanceID
                )

                await presentApplePay(intent: intent)
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isProcessing = false
                }
            }
        }
    }

    @MainActor
    private func presentApplePay(intent: ApplePayIntentResponseDTO) async {
        let paymentRequest = StripeAPI.paymentRequest(
            withMerchantIdentifier: Config.applePayMerchantID,
            country: "US",
            currency: "USD"
        )

        if #available(iOS 16.0, *) {
            let summaryAmount = NSDecimalNumber(value: Double(currentPrice) / 100.0)
            let summaryItem = PKRecurringPaymentSummaryItem(
                label: "\(subscriptionType.capitalized) Subscription",
                amount: summaryAmount
            )
            summaryItem.startDate = Date()
            summaryItem.intervalUnit = selectedFrequency == .monthly ? .month : .year
            summaryItem.intervalCount = 1

            let managementURL = URL(string: "https://sagebrush.services/app/subscriptions")
            let recurringRequest = PKRecurringPaymentRequest(
                paymentDescription: "Recurring subscription",
                regularBilling: summaryItem,
                managementURL: managementURL
            )
            recurringRequest.billingAgreement = "Your subscription renews automatically."
            paymentRequest.recurringPaymentRequest = recurringRequest
        }

        let totalAmount = NSDecimalNumber(value: Double(currentPrice) / 100.0)
        let summaryItem = PKPaymentSummaryItem(
            label: "\(subscriptionType.capitalized) Subscription (\(selectedFrequency.displayName))",
            amount: totalAmount
        )
        paymentRequest.paymentSummaryItems = [summaryItem]

        let coordinator = ApplePayContextCoordinator(
            clientSecret: intent.clientSecret,
            subscriptionId: intent.subscriptionId,
            apiClient: apiClient,
            onSuccess: { subscriptionID in
                do {
                    let subscriptions = try await apiClient.fetchSubscriptions()
                    if let subscription = subscriptions.first(where: { $0.id == subscriptionID }) {
                        await MainActor.run {
                            self.createdSubscription = subscription
                            self.paymentResult = PaymentResultDTO(
                                id: subscriptionID,
                                status: "succeeded",
                                amountCents: self.currentPrice,
                                processedAt: Date()
                            )
                            self.showingSuccess = true
                            self.isProcessing = false
                        }
                    } else {
                        await MainActor.run {
                            self.errorMessage = "Subscription confirmed but could not be loaded yet."
                            self.showingError = true
                            self.isProcessing = false
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.showingError = true
                        self.isProcessing = false
                    }
                }
            },
            onFailure: { error in
                await MainActor.run {
                    self.errorMessage = error
                    self.showingError = true
                    self.isProcessing = false
                }
            }
        )

        guard let applePayContext = STPApplePayContext(paymentRequest: paymentRequest, delegate: coordinator) else {
            errorMessage = "Apple Pay is not configured for this device"
            showingError = true
            isProcessing = false
            return
        }

        if let presenting = coordinator.presentingViewController as? UIViewController {
            applePayContext.presentApplePay(on: presenting)
        } else {
            applePayContext.presentApplePay(on: coordinator.presentingViewController)
        }
        withExtendedLifetime(coordinator) {}
    }
}

private final class ApplePayContextCoordinator: NSObject, STPApplePayContextDelegate {
    let clientSecret: String
    let subscriptionId: UUID
    let apiClient: APIClient
    let onSuccess: (UUID) async -> Void
    let onFailure: (String) async -> Void
    init(
        clientSecret: String,
        subscriptionId: UUID,
        apiClient: APIClient,
        onSuccess: @escaping (UUID) async -> Void,
        onFailure: @escaping (String) async -> Void
    ) {
        self.clientSecret = clientSecret
        self.subscriptionId = subscriptionId
        self.apiClient = apiClient
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }

    var presentingViewController: UIViewController {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController ?? UIViewController()
    }

    func applePayContext(
        _ context: STPApplePayContext,
        didCreatePaymentMethod paymentMethod: StripeAPI.PaymentMethod,
        paymentInformation: PKPayment
    ) async throws -> String {
        _ = paymentMethod
        return clientSecret
    }

    func applePayContext(
        _ context: STPApplePayContext,
        didCompleteWith status: STPApplePayContext.PaymentStatus,
        error: Error?
    ) {
        Task {
            switch status {
            case .success:
                do {
                    let confirmation = try await apiClient.confirmApplePayIntent(subscriptionId: subscriptionId)
                    await onSuccess(confirmation.subscriptionId)
                } catch {
                    await onFailure(error.localizedDescription)
                }
            case .error:
                await onFailure(error?.localizedDescription ?? "Apple Pay failed")
            case .userCancellation:
                await onFailure("Apple Pay was cancelled")
            @unknown default:
                await onFailure("Apple Pay failed")
            }
        }
    }

}

#Preview {
    SubscriptionView(
        subscriptionType: "mailbox",
        mailboxID: 123,
        flowInstanceID: nil
    )
}
#endif
