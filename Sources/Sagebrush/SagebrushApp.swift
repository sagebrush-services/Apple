import SwiftUI

struct SagebrushApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared

    init() {
        #if DEBUG
        if AppRuntimeMode.isScreenshotModeEnabled {
            UserDefaults.standard.set(true, forKey: "hasSeenWelcomeScreen")
            OnboardingManager.shared.hasSeenWelcome = true
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if AppRuntimeMode.isScreenshotModeEnabled {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(onboardingManager)
                    .preferredColorScheme(.light)
            } else {
                ContentView()
                    .environmentObject(authManager)
                    .environmentObject(onboardingManager)
            }
            #else
            ContentView()
                .environmentObject(authManager)
                .environmentObject(onboardingManager)
            #endif
        }
    }
}
