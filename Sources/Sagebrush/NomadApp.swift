import SwiftUI

@main
struct NomadApp: App {
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
