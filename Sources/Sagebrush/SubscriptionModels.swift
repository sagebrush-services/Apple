import Foundation

struct SubscriptionDTO: Codable, Identifiable {
    let id: UUID
    let subscriptionType: String
    let billingInterval: String
    let status: String
    let priceCents: Int
    let currency: String
    let nextBillingDate: Date?
    let xeroRepeatingInvoiceId: String?
    let stripeCustomerId: String?
    let stripeSubscriptionId: String?
    let stripePriceId: String?

    var displayPrice: String {
        let dollars = Double(priceCents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var displayInterval: String {
        switch billingInterval.lowercased() {
        case "monthly":
            return "per month"
        case "annual", "annually":
            return "per year"
        default:
            return billingInterval
        }
    }
}

struct CreateSubscriptionDTO: Codable {
    let type: String
    let frequency: String
    let mailboxID: Int32?
    let flowInstanceID: UUID?

    enum CodingKeys: String, CodingKey {
        case type
        case frequency
        case mailboxID = "mailbox_id"
        case flowInstanceID = "flow_instance_id"
    }
}

struct ProcessPaymentDTO: Codable {
    let paymentToken: String
    let paymentMethod: String

    enum CodingKeys: String, CodingKey {
        case paymentToken = "payment_token"
        case paymentMethod = "payment_method"
    }
}

struct PaymentResultDTO: Codable {
    let id: UUID
    let status: String
    let amountCents: Int
    let processedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case amountCents = "amount_cents"
        case processedAt = "processed_at"
    }

    var displayAmount: String {
        let dollars = Double(amountCents) / 100.0
        return String(format: "$%.2f", dollars)
    }
}
