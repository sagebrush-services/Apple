import Dali
import Foundation

@MainActor
class AdminAPIClient: ObservableObject {
    private let baseURL: URL
    private let authManager: AuthenticationManager
    private let keychain = KeychainService.shared

    init(baseURL: URL, authManager: AuthenticationManager) {
        self.baseURL = baseURL
        self.authManager = authManager
    }

    // MARK: - People Management

    func fetchPeople() async throws -> [Person] {
        try await makeAuthenticatedRequest(
            endpoint: "/admin/api/people",
            method: "GET"
        )
    }

    // MARK: - Questions Management

    func fetchQuestions() async throws -> [Question] {
        try await makeAuthenticatedRequest(
            endpoint: "/admin/api/questions",
            method: "GET"
        )
    }

    func createQuestion(_ question: Question) async throws -> Question {
        try await makeAuthenticatedRequest(
            endpoint: "/admin/api/questions",
            method: "POST",
            body: question
        )
    }

    func updateQuestion(_ question: Question) async throws -> Question {
        try await makeAuthenticatedRequest(
            endpoint: "/admin/api/questions/\(question.id ?? 0)",
            method: "PATCH",
            body: question
        )
    }

    func deleteQuestion(id: Int32) async throws {
        let _: EmptyResponse = try await makeAuthenticatedRequest(
            endpoint: "/admin/api/questions/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - Generic Request Helper

    private func makeAuthenticatedRequest<T: Codable>(
        endpoint: String,
        method: String,
        body: Encodable? = nil
    ) async throws -> T {
        // Get access token
        let accessToken = try await getValidAccessToken()

        // Build request
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(body)
        }

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Handle errors
        switch httpResponse.statusCode {
        case 200...299:
            if data.isEmpty {
                // For DELETE requests that return no content
                return EmptyResponse() as! T
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    private func getValidAccessToken() async throws -> String {
        // Check if current token is still valid
        if await keychain.hasValidTokens() {
            return try await keychain.load(.accessToken)
        }

        // Token expired, need to refresh
        try await authManager.refreshTokensIfNeeded()

        // Try loading token again
        return try await keychain.load(.accessToken)
    }
}

// MARK: - Error Types

enum APIError: LocalizedError {
    case unauthorized
    case forbidden
    case serverError(Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .forbidden:
            return "Admin access required for this action."
        case .serverError(let code):
            return "Server error (\(code))"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}

// MARK: - Helper Types

struct EmptyResponse: Codable {}
