import Foundation
import CryptoKit

struct PKCEGenerator {
    let codeVerifier: String
    let codeChallenge: String

    init() {
        // Generate code verifier: random 43-128 character string
        self.codeVerifier = PKCEGenerator.generateCodeVerifier()

        // Generate code challenge: base64url(sha256(codeVerifier))
        self.codeChallenge = PKCEGenerator.generateCodeChallenge(from: codeVerifier)
    }

    private static func generateCodeVerifier() -> String {
        // Generate 32 random bytes (will be 43 chars in base64url)
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        return Data(bytes)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else {
            fatalError("Failed to convert code verifier to data")
        }

        let hash = SHA256.hash(data: data)
        return Data(hash)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
