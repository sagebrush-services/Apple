import Dali
import Foundation
import Testing

@testable import Sagebrush

@Suite("AdminAPIClient Tests")
struct AdminAPIClientTests {

    // MARK: - Test Helpers

    /// Mock authentication manager for testing
    @MainActor
    class MockAuthenticationManager: AuthenticationManager {
        var mockAccessToken: String?
        var mockRefreshCalled = false

        override func refreshTokensIfNeeded() async throws {
            mockRefreshCalled = true
        }
    }

    /// Mock keychain service for testing
    actor MockKeychainService {
        var tokens: [String: String] = [:]

        func save(_ value: String, for key: String) async throws {
            tokens[key] = value
        }

        func load(_ key: String) async throws -> String {
            guard let value = tokens[key] else {
                throw KeychainError.itemNotFound
            }
            return value
        }

        func hasValidTokens() async -> Bool {
            return tokens["accessToken"] != nil
        }
    }

    enum KeychainError: Error {
        case itemNotFound
    }

    // MARK: - Request Construction Tests

    @Test("AdminAPIClient constructs correct endpoint URLs")
    @MainActor
    func testEndpointConstruction() async throws {
        let authManager = AuthenticationManager.shared
        let client = AdminAPIClient(
            baseURL: URL(string: "https://test.example.com")!,
            authManager: authManager
        )

        // Verify base URL is stored correctly
        #expect(client.baseURL.absoluteString == "https://test.example.com")
    }

    // MARK: - Error Handling Tests

    @Test("APIError provides correct error descriptions")
    func testAPIErrorDescriptions() {
        let unauthorizedError = APIError.unauthorized
        #expect(unauthorizedError.errorDescription == "Your session has expired. Please sign in again.")

        let forbiddenError = APIError.forbidden
        #expect(forbiddenError.errorDescription == "Admin access required for this action.")

        let serverError = APIError.serverError(500)
        #expect(serverError.errorDescription == "Server error (500)")

        let invalidResponseError = APIError.invalidResponse
        #expect(invalidResponseError.errorDescription == "Invalid server response")
    }

    // MARK: - Response Parsing Tests

    @Test("PersonResponse decodes correctly from JSON")
    func testPersonResponseDecoding() throws {
        let json = """
        {
            "id": 42,
            "name": "John Doe",
            "email": "john@example.com",
            "inserted_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-02T00:00:00Z"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let response = try decoder.decode(PersonResponse.self, from: data)

        #expect(response.id == 42)
        #expect(response.name == "John Doe")
        #expect(response.email == "john@example.com")
        #expect(response.insertedAt != nil)
        #expect(response.updatedAt != nil)
    }

    @Test("QuestionResponse decodes correctly from JSON")
    func testQuestionResponseDecoding() throws {
        let json = """
        {
            "id": 123,
            "prompt": "What is your name?",
            "question_type": "string",
            "code": "user_name",
            "help_text": "Enter your full legal name",
            "choices": null,
            "inserted_at": "2024-01-01T00:00:00Z",
            "updated_at": null
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let response = try decoder.decode(QuestionResponse.self, from: data)

        #expect(response.id == 123)
        #expect(response.prompt == "What is your name?")
        #expect(response.questionType == "string")
        #expect(response.code == "user_name")
        #expect(response.helpText == "Enter your full legal name")
        #expect(response.choices == nil)
        #expect(response.insertedAt != nil)
        #expect(response.updatedAt == nil)
    }

    @Test("QuestionResponse with choices decodes correctly")
    func testQuestionResponseWithChoicesDecoding() throws {
        let json = """
        {
            "id": 456,
            "prompt": "Select your state",
            "question_type": "select",
            "code": "state_selection",
            "help_text": null,
            "choices": {
                "CA": "California",
                "NY": "New York",
                "TX": "Texas"
            },
            "inserted_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-02T00:00:00Z"
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let response = try decoder.decode(QuestionResponse.self, from: data)

        #expect(response.id == 456)
        #expect(response.prompt == "Select your state")
        #expect(response.questionType == "select")
        #expect(response.code == "state_selection")
        #expect(response.helpText == nil)
        #expect(response.choices != nil)
        #expect(response.choices?["CA"] == "California")
        #expect(response.choices?["NY"] == "New York")
        #expect(response.choices?["TX"] == "Texas")
    }

    // MARK: - Request Encoding Tests

    @Test("CreatePersonRequest encodes correctly to JSON")
    func testCreatePersonRequestEncoding() throws {
        let request = CreatePersonRequest(
            name: "Jane Smith",
            email: "jane@example.com"
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"name\":\"Jane Smith\""))
        #expect(json.contains("\"email\":\"jane@example.com\""))
    }

    @Test("UpdatePersonRequest encodes correctly with partial data")
    func testUpdatePersonRequestEncoding() throws {
        let request = UpdatePersonRequest(
            name: "Updated Name",
            email: nil
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"name\":\"Updated Name\""))
        #expect(!json.contains("\"email\""))
    }

    @Test("UpdateQuestionRequest encodes correctly with all fields")
    func testUpdateQuestionRequestEncoding() throws {
        let request = UpdateQuestionRequest(
            prompt: "Updated prompt",
            questionType: .email,
            code: "updated_code",
            helpText: "Updated help",
            choices: ["A": "Option A", "B": "Option B"]
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(request)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains("\"prompt\":\"Updated prompt\""))
        #expect(json.contains("\"code\":\"updated_code\""))
        #expect(json.contains("\"help_text\":\"Updated help\""))
    }

    // MARK: - EmptyResponse Tests

    @Test("EmptyResponse can be created and encoded")
    func testEmptyResponse() throws {
        let response = EmptyResponse()
        let encoder = JSONEncoder()
        let data = try encoder.encode(response)
        let json = String(data: data, encoding: .utf8)!

        #expect(json == "{}")
    }

    // MARK: - URL Construction Tests

    @Test("Endpoint paths are correctly appended to base URL")
    func testEndpointPathConstruction() {
        let baseURL = URL(string: "https://api.example.com")!

        let peopleEndpoint = baseURL.appendingPathComponent("/admin/api/people")
        #expect(peopleEndpoint.absoluteString == "https://api.example.com/admin/api/people")

        let questionEndpoint = baseURL.appendingPathComponent("/admin/api/questions/123")
        #expect(questionEndpoint.path.contains("/admin/api/questions/123"))
    }
}

// MARK: - Helper Extensions for Testing

extension AdminAPIClient {
    var baseURL: URL {
        let mirror = Mirror(reflecting: self)
        if let value = mirror.descendant("baseURL") as? URL {
            return value
        }
        return AppConfiguration.shared.effectiveBaseURL
    }
}
