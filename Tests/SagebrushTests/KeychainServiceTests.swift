import Foundation
import Testing

@testable import Sagebrush

@Suite("KeychainService Tests", .serialized)
struct KeychainServiceTests {

    // MARK: - Setup/Teardown

    /// Clean up keychain before each test to ensure isolation
    init() async throws {
        let keychain = KeychainService.shared
        try await keychain.deleteAll()
    }

    // MARK: - Save and Load Tests

    @Test("Can save and load access token")
    func testSaveAndLoadAccessToken() async throws {
        let keychain = KeychainService.shared
        let testToken = "test-access-token-12345"

        try await keychain.save(testToken, for: .accessToken)
        let loaded = try await keychain.load(.accessToken)

        #expect(loaded == testToken)
    }

    @Test("Can save and load ID token")
    func testSaveAndLoadIDToken() async throws {
        let keychain = KeychainService.shared
        let testToken = "test-id-token-67890"

        try await keychain.save(testToken, for: .idToken)
        let loaded = try await keychain.load(.idToken)

        #expect(loaded == testToken)
    }

    @Test("Can save and load refresh token")
    func testSaveAndLoadRefreshToken() async throws {
        let keychain = KeychainService.shared
        let testToken = "test-refresh-token-abcdef"

        try await keychain.save(testToken, for: .refreshToken)
        let loaded = try await keychain.load(.refreshToken)

        #expect(loaded == testToken)
    }

    @Test("Can save and load multiple tokens independently")
    func testSaveAndLoadMultipleTokens() async throws {
        let keychain = KeychainService.shared
        let accessToken = "access-token-123"
        let idToken = "id-token-456"
        let refreshToken = "refresh-token-789"

        try await keychain.save(accessToken, for: .accessToken)
        try await keychain.save(idToken, for: .idToken)
        try await keychain.save(refreshToken, for: .refreshToken)

        let loadedAccess = try await keychain.load(.accessToken)
        let loadedID = try await keychain.load(.idToken)
        let loadedRefresh = try await keychain.load(.refreshToken)

        #expect(loadedAccess == accessToken)
        #expect(loadedID == idToken)
        #expect(loadedRefresh == refreshToken)
    }

    @Test("Saving over existing value updates the value")
    func testSaveOverwritesExistingValue() async throws {
        let keychain = KeychainService.shared
        let originalToken = "original-token"
        let updatedToken = "updated-token"

        try await keychain.save(originalToken, for: .accessToken)
        try await keychain.save(updatedToken, for: .accessToken)
        let loaded = try await keychain.load(.accessToken)

        #expect(loaded == updatedToken)
        #expect(loaded != originalToken)
    }

    // MARK: - Date Save and Load Tests

    @Test("Can save and load Date as token expiration")
    func testSaveAndLoadDate() async throws {
        let keychain = KeychainService.shared
        let testDate = Date(timeIntervalSince1970: 1700000000) // Nov 14, 2023

        try await keychain.saveDate(testDate, for: .tokenExpiration)
        let loaded = try await keychain.loadDate(.tokenExpiration)

        // Compare timestamps (rounded to nearest second)
        #expect(Int(loaded.timeIntervalSince1970) == Int(testDate.timeIntervalSince1970))
    }

    @Test("Can save and load future date")
    func testSaveAndLoadFutureDate() async throws {
        let keychain = KeychainService.shared
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now

        try await keychain.saveDate(futureDate, for: .tokenExpiration)
        let loaded = try await keychain.loadDate(.tokenExpiration)

        #expect(Int(loaded.timeIntervalSince1970) == Int(futureDate.timeIntervalSince1970))
    }

    @Test("Can save and load past date")
    func testSaveAndLoadPastDate() async throws {
        let keychain = KeychainService.shared
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago

        try await keychain.saveDate(pastDate, for: .tokenExpiration)
        let loaded = try await keychain.loadDate(.tokenExpiration)

        #expect(Int(loaded.timeIntervalSince1970) == Int(pastDate.timeIntervalSince1970))
    }

    // MARK: - Delete Tests

    @Test("Can delete individual token")
    func testDeleteIndividualToken() async throws {
        let keychain = KeychainService.shared
        let testToken = "token-to-delete"

        try await keychain.save(testToken, for: .accessToken)
        try await keychain.delete(.accessToken)

        // Loading deleted token should throw notFound error
        await #expect(throws: KeychainService.KeychainError.notFound) {
            try await keychain.load(.accessToken)
        }
    }

    @Test("Delete does not affect other tokens")
    func testDeleteDoesNotAffectOtherTokens() async throws {
        let keychain = KeychainService.shared
        let accessToken = "access-token"
        let idToken = "id-token"

        try await keychain.save(accessToken, for: .accessToken)
        try await keychain.save(idToken, for: .idToken)

        try await keychain.delete(.accessToken)

        // ID token should still be loadable
        let loadedID = try await keychain.load(.idToken)
        #expect(loadedID == idToken)

        // Access token should be gone
        await #expect(throws: KeychainService.KeychainError.notFound) {
            try await keychain.load(.accessToken)
        }
    }

    @Test("Can delete all tokens")
    func testDeleteAllTokens() async throws {
        let keychain = KeychainService.shared

        // Save all token types
        try await keychain.save("access", for: .accessToken)
        try await keychain.save("id", for: .idToken)
        try await keychain.save("refresh", for: .refreshToken)
        try await keychain.saveDate(Date(), for: .tokenExpiration)

        try await keychain.deleteAll()

        // All tokens should be gone
        for key in [KeychainService.Key.accessToken, .idToken, .refreshToken, .tokenExpiration] {
            await #expect(throws: KeychainService.KeychainError.notFound) {
                try await keychain.load(key)
            }
        }
    }

    @Test("Deleting non-existent token does not throw error")
    func testDeleteNonExistentToken() async throws {
        let keychain = KeychainService.shared

        // Should not throw - delete is idempotent
        try await keychain.delete(.accessToken)
    }

    // MARK: - Error Handling Tests

    @Test("Loading non-existent token throws notFound error")
    func testLoadNonExistentToken() async throws {
        let keychain = KeychainService.shared

        // Ensure the key doesn't exist from previous tests
        try? await keychain.delete(.accessToken)

        // Verify that loading non-existent token throws notFound error
        await #expect(throws: KeychainService.KeychainError.notFound) {
            try await keychain.load(.accessToken)
        }
    }

    @Test("Loading non-existent date throws notFound error")
    func testLoadNonExistentDate() async throws {
        let keychain = KeychainService.shared

        // Ensure the key doesn't exist from previous tests
        try? await keychain.delete(.tokenExpiration)

        // Verify that loading non-existent date throws notFound error
        await #expect(throws: KeychainService.KeychainError.notFound) {
            try await keychain.loadDate(.tokenExpiration)
        }
    }

    // MARK: - Token Validity Tests

    @Test("hasValidTokens returns false when no expiration exists")
    func testHasValidTokensWithNoExpiration() async throws {
        let keychain = KeychainService.shared

        // Ensure no expiration date exists from previous tests
        try? await keychain.delete(.tokenExpiration)

        let isValid = await keychain.hasValidTokens()
        #expect(isValid == false)
    }

    @Test("hasValidTokens returns true for future expiration (>5 minutes)")
    func testHasValidTokensWithFutureExpiration() async throws {
        let keychain = KeychainService.shared
        let futureDate = Date().addingTimeInterval(600) // 10 minutes from now

        try await keychain.saveDate(futureDate, for: .tokenExpiration)

        let isValid = await keychain.hasValidTokens()
        #expect(isValid == true)
    }

    @Test("hasValidTokens returns false for expired tokens")
    func testHasValidTokensWithPastExpiration() async throws {
        let keychain = KeychainService.shared
        let pastDate = Date().addingTimeInterval(-600) // 10 minutes ago

        try await keychain.saveDate(pastDate, for: .tokenExpiration)

        let isValid = await keychain.hasValidTokens()
        #expect(isValid == false)
    }

    @Test("hasValidTokens returns false for tokens expiring within 5 minutes")
    func testHasValidTokensWithNearExpiration() async throws {
        let keychain = KeychainService.shared
        let nearExpirationDate = Date().addingTimeInterval(200) // 3.33 minutes from now

        try await keychain.saveDate(nearExpirationDate, for: .tokenExpiration)

        let isValid = await keychain.hasValidTokens()
        #expect(isValid == false)
    }

    @Test("hasValidTokens boundary case: exactly 5 minutes")
    func testHasValidTokensBoundaryCase() async throws {
        let keychain = KeychainService.shared
        let boundaryDate = Date().addingTimeInterval(300) // Exactly 5 minutes

        try await keychain.saveDate(boundaryDate, for: .tokenExpiration)

        let isValid = await keychain.hasValidTokens()
        // Should be false because > 300, not >= 300
        #expect(isValid == false)
    }

    @Test("hasValidTokens boundary case: 5 minutes + 1 second")
    func testHasValidTokensJustValid() async throws {
        let keychain = KeychainService.shared
        let justValidDate = Date().addingTimeInterval(301) // 5 minutes + 1 second

        try await keychain.saveDate(justValidDate, for: .tokenExpiration)

        let isValid = await keychain.hasValidTokens()
        #expect(isValid == true)
    }

    // MARK: - Key Enum Tests

    @Test("Key enum has correct raw values")
    func testKeyEnumRawValues() {
        #expect(KeychainService.Key.accessToken.rawValue == "cognito_access_token")
        #expect(KeychainService.Key.idToken.rawValue == "cognito_id_token")
        #expect(KeychainService.Key.refreshToken.rawValue == "cognito_refresh_token")
        #expect(KeychainService.Key.tokenExpiration.rawValue == "token_expiration")
    }

    // MARK: - Special Characters Tests

    @Test("Can save and load tokens with special characters")
    func testSaveAndLoadTokensWithSpecialCharacters() async throws {
        let keychain = KeychainService.shared
        let specialToken = "token_with-special.chars+and/symbols=123"

        try await keychain.save(specialToken, for: .accessToken)
        let loaded = try await keychain.load(.accessToken)

        #expect(loaded == specialToken)
    }

    @Test("Can save and load very long tokens")
    func testSaveAndLoadLongToken() async throws {
        let keychain = KeychainService.shared
        // Cognito tokens can be quite long
        let longToken = String(repeating: "abcdefghij", count: 100) // 1000 characters

        try await keychain.save(longToken, for: .accessToken)
        let loaded = try await keychain.load(.accessToken)

        #expect(loaded == longToken)
        #expect(loaded.count == 1000)
    }

    @Test("Can save and load tokens with unicode characters")
    func testSaveAndLoadUnicodeToken() async throws {
        let keychain = KeychainService.shared
        let unicodeToken = "token-with-émojis-🔐-and-spëcial-çhars"

        try await keychain.save(unicodeToken, for: .accessToken)
        let loaded = try await keychain.load(.accessToken)

        #expect(loaded == unicodeToken)
    }
}
