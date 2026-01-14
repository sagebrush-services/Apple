import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var showingWelcomeOnFirstLaunch = false

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                DashboardShellView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            if !onboardingManager.hasSeenWelcome {
                showingWelcomeOnFirstLaunch = true
            }
        }
        .sheet(isPresented: $showingWelcomeOnFirstLaunch) {
            WelcomeView {
                showingWelcomeOnFirstLaunch = false
            }
            .environmentObject(onboardingManager)
        }
    }
}
