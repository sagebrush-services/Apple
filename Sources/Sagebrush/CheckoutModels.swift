import Foundation

struct CheckoutSessionRequestDTO: Codable {
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

struct CheckoutSessionResponseDTO: Codable {
    let checkoutSessionId: String
    let clientSecret: String

    enum CodingKeys: String, CodingKey {
        case checkoutSessionId = "checkout_session_id"
        case clientSecret = "client_secret"
    }
}

struct CheckoutConfirmRequestDTO: Codable {
    let checkoutSessionId: String

    enum CodingKeys: String, CodingKey {
        case checkoutSessionId = "checkout_session_id"
    }
}

struct CheckoutConfirmResponseDTO: Codable {
    let subscriptionId: UUID

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
    }
}

struct ApplePayIntentResponseDTO: Codable {
    let subscriptionId: UUID
    let clientSecret: String

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
        case clientSecret = "client_secret"
    }
}

struct ApplePayConfirmRequestDTO: Codable {
    let subscriptionId: UUID

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
    }
}

struct ApplePayConfirmResponseDTO: Codable {
    let subscriptionId: UUID

    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
    }
}

struct StripePublishableKeyResponseDTO: Codable {
    let publishableKey: String

    enum CodingKeys: String, CodingKey {
        case publishableKey = "publishable_key"
    }
}
