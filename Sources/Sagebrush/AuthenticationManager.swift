import Foundation
import AuthenticationServices
import SwiftUI
import Dali

@MainActor
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()

    @Published var isAuthenticated = false
    @Published var userEmail: String?
    @Published var userGroups: [String]?
    @Published var userGivenName: String?

    // MARK: - Role Computation

    /// Current user role derived from Cognito groups
    var currentRole: UserRole {
        guard let groups = userGroups else { return .customer }
        return determineRole(from: groups)
    }

    /// Check if current user is an admin
    var isAdmin: Bool {
        currentRole == .admin
    }

    /// Check if current user is a customer
    var isCustomer: Bool {
        currentRole == .customer
    }

    /// Determine user role from Cognito groups (matches server-side logic)
    private func determineRole(from groups: [String]) -> UserRole {
        let normalized = groups.map {
            $0.lowercased().trimmingCharacters(in: .whitespaces)
        }

        // Check for admin role first (highest precedence)
        if normalized.contains(where: { $0 == "admin" || $0 == "admins" }) {
            return .admin
        }

        // Default to customer
        return .customer
    }

    private let keychain = KeychainService.shared
    private let config = Config.environment.cognitoConfig

    private var authSession: ASWebAuthenticationSession?
    private var pkce: PKCEGenerator?

    private override init() {
        super.init()
        Task {
            await checkAuthenticationStatus()
        }
    }

    // MARK: - Public Methods

    func signIn() async throws {
        // Generate PKCE codes
        let pkce = PKCEGenerator()
        self.pkce = pkce

        // Build authorization URL
        let authURL = try buildAuthorizationURL(pkce: pkce)

        // Create authentication session
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "sagebrush"
            ) { callbackURL, error in
                Task { @MainActor in
                    if let error = error {
                        if let authError = error as? ASWebAuthenticationSessionError,
                           authError.code == .canceledLogin {
                            continuation.resume(throwing: AuthError.userCancelled)
                        } else {
                            continuation.resume(throwing: AuthError.authenticationFailed(error))
                        }
                        return
                    }

                    guard let callbackURL = callbackURL else {
                        continuation.resume(throwing: AuthError.invalidCallback)
                        return
                    }

                    do {
                        try await self.handleCallback(callbackURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            self.authSession = session

            if !session.start() {
                continuation.resume(throwing: AuthError.sessionStartFailed)
            }
        }
    }

    func signOut() async throws {
        // Revoke refresh token with Cognito
        if let refreshToken = try? await keychain.load(.refreshToken) {
            try? await revokeToken(refreshToken)
        }

        // Clear all tokens from keychain
        try await keychain.deleteAll()

        // Update state
        isAuthenticated = false
        userEmail = nil
        userGroups = nil
        userGivenName = nil

        // Optional: Redirect to Cognito logout (clears Cognito session)
        // await redirectToCognitoLogout()
    }

    func refreshTokensIfNeeded() async throws {
        guard await keychain.hasValidTokens() else {
            // Tokens expired, need refresh
            try await refreshTokens()
            return
        }
    }

    // MARK: - Private Methods

    private func checkAuthenticationStatus() async {
        do {
            if await keychain.hasValidTokens() {
                // Load and validate tokens
                try await refreshTokensIfNeeded()
                try await loadUserInfo()
                isAuthenticated = true
            } else {
                isAuthenticated = false
            }
        } catch {
            isAuthenticated = false
        }
    }

    private func handleCallback(_ url: URL) async throws {
        // Extract authorization code from callback URL
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value else {
            throw AuthError.invalidCallback
        }

        // Exchange code for tokens
        try await exchangeCodeForTokens(code)
    }

    private func exchangeCodeForTokens(_ code: String) async throws {
        guard let pkce = pkce else {
            throw AuthError.missingPKCE
        }

        // Build token request
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "authorization_code",
            "client_id": config.clientId,
            "code": code,
            "redirect_uri": config.redirectURI,
            "code_verifier": pkce.codeVerifier,
        ]

        request.httpBody = formURLEncodedBody(bodyParams)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenExchangeFailed
        }

        // Parse token response
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Save tokens securely
        try await saveTokens(tokenResponse)

        // Load user info
        try await loadUserInfo()

        // Update state
        isAuthenticated = true

        // Clear PKCE codes
        self.pkce = nil
    }

    private func refreshTokens() async throws {
        guard let refreshToken = try? await keychain.load(.refreshToken) else {
            throw AuthError.noRefreshToken
        }

        // Build refresh request
        var request = URLRequest(url: URL(string: config.tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "grant_type": "refresh_token",
            "client_id": config.clientId,
            "refresh_token": refreshToken,
        ]

        request.httpBody = formURLEncodedBody(bodyParams)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Refresh failed, need to re-authenticate
            try await keychain.deleteAll()
            isAuthenticated = false
            throw AuthError.refreshFailed
        }

        // Parse token response
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Save new tokens (refresh token may have rotated)
        try await saveTokens(tokenResponse)
    }

    private func saveTokens(_ response: TokenResponse) async throws {
        try await keychain.save(response.accessToken, for: .accessToken)
        try await keychain.save(response.idToken, for: .idToken)

        if let refreshToken = response.refreshToken {
            try await keychain.save(refreshToken, for: .refreshToken)
        }

        // Calculate expiration time
        let expirationDate = Date().addingTimeInterval(TimeInterval(response.expiresIn))
        try await keychain.saveDate(expirationDate, for: .tokenExpiration)
    }

    private func loadUserInfo() async throws {
        // Decode ID token to get user info (JWT)
        guard let idToken = try? await keychain.load(.idToken) else {
            throw AuthError.noTokens
        }

        let claims = try decodeJWT(idToken)

        // Extract user info from claims
        userEmail = claims["email"] as? String

        if let givenName = (claims["given_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !givenName.isEmpty {
            userGivenName = givenName
        } else if let fullName = (claims["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !fullName.isEmpty {
            userGivenName = fullName.components(separatedBy: .whitespaces).first
        } else if let email = userEmail,
                  let handle = email.split(separator: "@").first,
                  !handle.isEmpty {
            userGivenName = String(handle)
        } else {
            userGivenName = nil
        }

        // Extract Cognito groups
        if let groups = claims["cognito:groups"] as? [String] {
            userGroups = groups
        }
    }

    private func decodeJWT(_ jwt: String) throws -> [String: Any] {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count == 3 else {
            throw AuthError.invalidToken
        }

        // Decode payload (second segment)
        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AuthError.invalidToken
        }

        return json
    }

    private func revokeToken(_ token: String) async throws {
        var request = URLRequest(url: URL(string: config.revokeEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "token": token,
            "client_id": config.clientId,
        ]

        request.httpBody = formURLEncodedBody(bodyParams)

        _ = try await URLSession.shared.data(for: request)
    }

    // MARK: - Helper Types

    struct TokenResponse: Codable {
        let accessToken: String
        let idToken: String
        let refreshToken: String?
        let expiresIn: Int

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case idToken = "id_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
        }
    }

    enum AuthError: LocalizedError {
        case invalidURL
        case userCancelled
        case authenticationFailed(Error)
        case invalidCallback
        case sessionStartFailed
        case missingPKCE
        case tokenExchangeFailed
        case noRefreshToken
        case refreshFailed
        case noTokens
        case invalidToken

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid authentication URL"
            case .userCancelled:
                return "Sign in was cancelled"
            case .authenticationFailed(let error):
                return "Authentication failed: \(error.localizedDescription)"
            case .invalidCallback:
                return "Invalid callback from authentication"
            case .sessionStartFailed:
                return "Failed to start authentication session"
            case .missingPKCE:
                return "Missing PKCE codes"
            case .tokenExchangeFailed:
                return "Failed to exchange code for tokens"
            case .noRefreshToken:
                return "No refresh token available"
            case .refreshFailed:
                return "Token refresh failed. Please sign in again."
            case .noTokens:
                return "No authentication tokens found"
            case .invalidToken:
                return "Invalid token format"
            }
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension AuthenticationManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Return the key window for presenting the authentication UI
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

// MARK: - Private helpers

private extension AuthenticationManager {
    func buildAuthorizationURL(pkce: PKCEGenerator) throws -> URL {
        let params: [String: String] = [
            "client_id": config.clientId,
            "response_type": "code",
            "scope": "openid email profile",
            "redirect_uri": config.redirectURI,
            "code_challenge": pkce.codeChallenge,
            "code_challenge_method": "S256",
        ]

        let query = params
            .map { key, value in "\(key)=\(percentEncode(value))" }
            .sorted()
            .joined(separator: "&")

        let urlString = "\(config.authorizationEndpoint)?\(query)"
        guard let url = URL(string: urlString) else {
            throw AuthError.invalidURL
        }
        return url
    }

    func formURLEncodedBody(_ params: [String: String]) -> Data? {
        let encoded = params
            .map { key, value in "\(key)=\(percentEncode(value))" }
            .joined(separator: "&")
        return encoded.data(using: .utf8)
    }

    func percentEncode(_ value: String) -> String {
        // For redirect URIs, we should not encode the scheme and path separators
        // OAuth spec requires these to match exactly as registered
        if value.hasPrefix("sagebrush://") {
            // Don't encode redirect URIs - they must match exactly as registered in Cognito
            return value
        }

        // For other parameters, use standard URL encoding
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&="))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
