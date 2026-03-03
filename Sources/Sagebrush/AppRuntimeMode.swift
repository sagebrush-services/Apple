import Foundation

enum AppRuntimeMode {
    // First delivery target is a standalone TestFlight demo app.
    // Can be overridden by setting SAGEBRUSH_STANDALONE_DEMO=0.
    static var isStandaloneDemoEnabled: Bool {
        guard let raw = ProcessInfo.processInfo.environment["SAGEBRUSH_STANDALONE_DEMO"] else {
            return true
        }
        return Self.parseTruthy(raw, defaultValue: true)
    }

    static var isScreenshotModeEnabled: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--screenshot-mode") {
            return true
        }
        if let raw = ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] {
            return parseTruthy(raw, defaultValue: false)
        }
        return false
        #else
        return false
        #endif
    }

    private static func parseTruthy(_ raw: String, defaultValue: Bool) -> Bool {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return defaultValue
        }
    }
}
