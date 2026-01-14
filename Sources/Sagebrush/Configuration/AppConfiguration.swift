import Foundation

/// Application configuration for different environments
@MainActor
class AppConfiguration {
    static let shared = AppConfiguration()

    /// Current environment (read from build configuration or Info.plist)
    private(set) var environment: Environment

    /// API base URL for the current environment
    var apiBaseURL: URL {
        switch environment {
        case .development:
            // iOS Simulator can access localhost directly (shares host network stack)
            // For real devices, use your Mac's local network IP (e.g., "http://192.168.1.100:8080")
            return URL(string: "http://localhost:8080")!
        case .staging:
            return URL(string: "https://staging.sagebrush.services")!
        case .production:
            return URL(string: "https://sagebrush.services")!
        }
    }

    private init() {
        // Determine environment from build configuration
        #if DEBUG
        // Check if running on simulator vs real device
        #if targetEnvironment(simulator)
        self.environment = .development
        #else
        // Real device in debug mode - you might want staging or local network IP
        self.environment = .development
        #endif
        #else
        self.environment = .production
        #endif
    }

    /// Override environment (useful for testing)
    func setEnvironment(_ env: Environment) {
        self.environment = env
    }

    /// Override base URL (useful for testing or custom configurations)
    func setCustomBaseURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            return false
        }
        self.customBaseURL = url
        return true
    }

    private var customBaseURL: URL?

    /// Get the effective base URL (custom or environment-based)
    var effectiveBaseURL: URL {
        customBaseURL ?? apiBaseURL
    }
}

/// Application environments
enum Environment: String {
    case development = "Development"
    case staging = "Staging"
    case production = "Production"
}

// MARK: - Development Network Configuration

extension AppConfiguration {
    /// For real iOS devices on your local network, set this to your Mac's IP
    /// Find your Mac's IP: System Settings → Network → WiFi → Details
    /// Example: "http://192.168.1.100:8080"
    ///
    /// To use this, call in your app startup:
    /// ```
    /// AppConfiguration.shared.useLocalNetworkIP("192.168.1.100")
    /// ```
    func useLocalNetworkIP(_ ip: String, port: Int = 8080) -> Bool {
        return setCustomBaseURL("http://\(ip):\(port)")
    }

    /// Get current configuration summary (useful for debugging)
    var configurationSummary: String {
        """
        Environment: \(environment.rawValue)
        Base URL: \(effectiveBaseURL.absoluteString)
        Is Custom URL: \(customBaseURL != nil)
        """
    }
}
