import Foundation
import SwiftUI

@MainActor
class APIClient: ObservableObject {
    static let shared = APIClient()

    private let baseURL: URL
    private let keychain = KeychainService.shared

    private init() {
        self.baseURL = URL(string: Config.environment.apiBaseURL)!
    }

    // MARK: - Public API Methods

    func fetchDashboardSnapshot() async throws -> DashboardSnapshotDTO {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try await makeAuthenticatedJSONRequest(
            method: "GET",
            endpoint: "/api/v1.0/dashboard",
            decoder: decoder
        )
    }

    func fetchAccountSummary() async throws -> AccountSummaryDTO {
        try await makeAuthenticatedJSONRequest(
            method: "GET",
            endpoint: "/api/v1.0/account"
        )
    }

    func updateAccountName(_ name: String) async throws -> AccountSummaryDTO {
        let payload = try JSONEncoder().encode(["name": name])
        return try await makeAuthenticatedJSONRequest(
            method: "PATCH",
            endpoint: "/api/v1.0/account",
            body: payload
        )
    }

    func fetchMailboxes() async throws -> [MailboxSummaryDTO] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try await makeAuthenticatedJSONRequest(
            method: "GET",
            endpoint: "/api/v1.0/mailboxes",
            decoder: decoder
        )
    }

    // MARK: - Private Methods

    func makeAuthenticatedRequest(
        method: String,
        endpoint: String,
        body: Data? = nil
    ) async throws -> String {
        let data = try await makeAuthenticatedRequestData(method: method, endpoint: endpoint, body: body)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func makeAuthenticatedRequestData(
        method: String,
        endpoint: String,
        body: Data? = nil
    ) async throws -> Data {
        let accessToken = try await getValidAccessToken()

        guard let url = URL(string: endpoint, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = body {
            request.httpBody = body
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            try await AuthenticationManager.shared.refreshTokensIfNeeded()
            let newAccessToken = try await getValidAccessToken()
            request.setValue("Bearer \(newAccessToken)", forHTTPHeaderField: "Authorization")

            let (retryData, retryResponse) = try await URLSession.shared.data(for: request)

            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard retryHttpResponse.statusCode == 200 else {
                throw APIError.httpError(retryHttpResponse.statusCode)
            }

            return retryData
        }

        guard httpResponse.statusCode == 200 else {
            let bodyPreview = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            print(
                "⚠️ API request failed",
                request.httpMethod ?? "GET",
                endpoint,
                "status:",
                httpResponse.statusCode,
                "body:",
                bodyPreview
            )
            throw APIError.httpError(httpResponse.statusCode)
        }

        return data
    }

    func makeAuthenticatedJSONRequest<T: Decodable>(
        method: String,
        endpoint: String,
        body: Data? = nil,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let data = try await makeAuthenticatedRequestData(method: method, endpoint: endpoint, body: body)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func getValidAccessToken() async throws -> String {
        // Check if current token is still valid
        if await keychain.hasValidTokens() {
            return try await keychain.load(.accessToken)
        }

        // Token expired, need to refresh
        try await AuthenticationManager.shared.refreshTokensIfNeeded()

        // Try loading token again
        return try await keychain.load(.accessToken)
    }

    // MARK: - Error Types

    enum APIError: LocalizedError {
        case invalidResponse
        case invalidURL
        case httpError(Int)
        case noAccessToken
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "Invalid response from server"
            case .invalidURL:
                return "Invalid API endpoint"
            case .httpError(let code):
                return "HTTP error: \(code)"
            case .noAccessToken:
                return "No access token available"
            case .decodingFailed:
                return "Failed to decode response"
            }
        }
    }
}
