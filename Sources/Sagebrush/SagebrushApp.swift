import SwiftUI

@main
struct SagebrushApp: App {
    @StateObject private var authManager = AuthenticationManager.shared
    @StateObject private var onboardingManager = OnboardingManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(onboardingManager)
        }
    }
}
