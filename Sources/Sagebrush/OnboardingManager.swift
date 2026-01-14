import Foundation
import SwiftUI

@MainActor
class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    @Published var hasSeenWelcome: Bool {
        didSet {
            UserDefaults.standard.set(hasSeenWelcome, forKey: "hasSeenWelcomeScreen")
        }
    }

    @Published var showWelcomeSheet = false

    private init() {
        self.hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenWelcomeScreen")
    }

    func markWelcomeAsSeen() {
        hasSeenWelcome = true
    }

    func showWelcome() {
        showWelcomeSheet = true
    }

    func resetOnboarding() {
        hasSeenWelcome = false
    }
}
