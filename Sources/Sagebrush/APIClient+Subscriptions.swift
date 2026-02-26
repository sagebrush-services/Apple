import Foundation

// MARK: - Subscriptions API v1.0
//
// All endpoints use the versioned API base path: /api/v1.0/subscriptions

extension APIClient {
    func createCheckoutSession(
        type: String,
        frequency: String,
        mailboxID: Int32? = nil,
        flowInstanceID: UUID? = nil
    ) async throws -> CheckoutSessionResponseDTO {
        let request = CheckoutSessionRequestDTO(
            type: type,
            frequency: frequency,
            mailboxID: mailboxID,
            flowInstanceID: flowInstanceID
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try await makeAuthenticatedJSONRequest(
            method: "POST",
            endpoint: "/api/v1.0/checkout/session",
            body: data,
            decoder: decoder
        )
    }

    func confirmCheckoutSession(sessionId: String) async throws -> CheckoutConfirmResponseDTO {
        let request = CheckoutConfirmRequestDTO(checkoutSessionId: sessionId)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try await makeAuthenticatedJSONRequest(
            method: "POST",
            endpoint: "/api/v1.0/checkout/confirm",
            body: data,
            decoder: decoder
        )
    }

    func createApplePayIntent(
        type: String,
        frequency: String,
        mailboxID: Int32? = nil,
        flowInstanceID: UUID? = nil
    ) async throws -> ApplePayIntentResponseDTO {
        let request = CheckoutSessionRequestDTO(
            type: type,
            frequency: frequency,
            mailboxID: mailboxID,
            flowInstanceID: flowInstanceID
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try await makeAuthenticatedJSONRequest(
            method: "POST",
            endpoint: "/api/v1.0/checkout/apple-pay",
            body: data,
            decoder: decoder
        )
    }

    func confirmApplePayIntent(subscriptionId: UUID) async throws -> ApplePayConfirmResponseDTO {
        let request = ApplePayConfirmRequestDTO(subscriptionId: subscriptionId)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try await makeAuthenticatedJSONRequest(
            method: "POST",
            endpoint: "/api/v1.0/checkout/apple-pay/confirm",
            body: data,
            decoder: decoder
        )
    }

    func fetchStripePublishableKey() async throws -> StripePublishableKeyResponseDTO {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try await makeJSONRequest(
            method: "GET",
            endpoint: "/api/v1.0/checkout/publishable-key",
            decoder: decoder
        )
    }
    func createSubscription(
        type: String,
        frequency: String,
        mailboxID: Int32? = nil,
        flowInstanceID: UUID? = nil
    ) async throws -> SubscriptionDTO {
        let request = CreateSubscriptionDTO(
            type: type,
            frequency: frequency,
            mailboxID: mailboxID,
            flowInstanceID: flowInstanceID
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try await makeAuthenticatedJSONRequest(
            method: "POST",
            endpoint: "/api/v1.0/subscriptions",
            body: data,
            decoder: decoder
        )
    }

    func processPayment(
        subscriptionID: UUID,
        paymentToken: String,
        paymentMethod: String
    ) async throws -> PaymentResultDTO {
        let request = ProcessPaymentDTO(
            paymentToken: paymentToken,
            paymentMethod: paymentMethod
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try await makeAuthenticatedJSONRequest(
            method: "POST",
            endpoint: "/api/v1.0/subscriptions/\(subscriptionID.uuidString)/payment",
            body: data,
            decoder: decoder
        )
    }

    func fetchSubscriptions() async throws -> [SubscriptionDTO] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        return try await makeAuthenticatedJSONRequest(
            method: "GET",
            endpoint: "/api/v1.0/subscriptions",
            decoder: decoder
        )
    }

    func cancelSubscription(id: UUID) async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let _: SubscriptionDTO = try await makeAuthenticatedJSONRequest(
            method: "DELETE",
            endpoint: "/api/v1.0/subscriptions/\(id.uuidString)",
            decoder: decoder
        )
    }
}
