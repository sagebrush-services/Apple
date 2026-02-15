import Foundation
import Security

actor KeychainService {
    static let shared = KeychainService()

    private let service = "com.sagebrush.nomad"
    private let useInMemoryStore: Bool
    private var inMemoryStore: [Key: String]

    enum KeychainError: Error, Equatable {
        case encodingFailed
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case notFound
    }

    enum Key: String {
        case accessToken = "cognito_access_token"
        case idToken = "cognito_id_token"
        case refreshToken = "cognito_refresh_token"
        case tokenExpiration = "token_expiration"
    }

    init() {
        // When running under tests (XCTest or Swift Testing), use in-memory storage to avoid Keychain side effects.
        let isXCTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        let isSwiftTesting = ProcessInfo.processInfo.processName.hasSuffix("PackageTests")

        if isXCTest || isSwiftTesting {
            self.useInMemoryStore = true
            self.inMemoryStore = [:]
        } else {
            self.useInMemoryStore = false
            self.inMemoryStore = [:]
        }
    }

    // MARK: - Save

    func save(_ value: String, for key: Key) throws {
        if useInMemoryStore {
            inMemoryStore[key] = value
            return
        }
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        // Delete existing item first
        try? delete(key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: service,
            kSecValueData as String: data,
        ]

        // Refresh token gets extra protection
        if key == .refreshToken {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        } else {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func saveDate(_ date: Date, for key: Key) throws {
        let timestamp = String(date.timeIntervalSince1970)
        try save(timestamp, for: key)
    }

    // MARK: - Load

    func load(_ key: Key) throws -> String {
        if useInMemoryStore {
            guard let value = inMemoryStore[key] else {
                throw KeychainError.notFound
            }
            return value
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.notFound
            }
            throw KeychainError.loadFailed(status)
        }

        guard let data = result as? Data,
            let string = String(data: data, encoding: .utf8)
        else {
            throw KeychainError.loadFailed(status)
        }

        return string
    }

    func loadDate(_ key: Key) throws -> Date {
        let timestamp = try load(key)
        guard let interval = TimeInterval(timestamp) else {
            throw KeychainError.loadFailed(errSecInvalidData)
        }
        return Date(timeIntervalSince1970: interval)
    }

    // MARK: - Delete

    func delete(_ key: Key) throws {
        if useInMemoryStore {
            inMemoryStore.removeValue(forKey: key)
            return
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrService as String: service,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func deleteAll() throws {
        if useInMemoryStore {
            inMemoryStore.removeAll()
            return
        }
        for key in [Key.accessToken, .idToken, .refreshToken, .tokenExpiration] {
            try? delete(key)
        }
    }

    // MARK: - Helper Methods

    func hasValidTokens() async -> Bool {
        if useInMemoryStore {
            guard let expirationString = inMemoryStore[.tokenExpiration],
                let interval = TimeInterval(expirationString)
            else {
                return false
            }
            return Date(timeIntervalSince1970: interval).timeIntervalSinceNow > 300
        }
        do {
            let expiration = try loadDate(.tokenExpiration)
            // Check if token expires in more than 5 minutes
            return expiration.timeIntervalSinceNow > 300
        } catch {
            return false
        }
    }
}
