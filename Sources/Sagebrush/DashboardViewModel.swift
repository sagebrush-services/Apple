import Foundation
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var snapshot: DashboardSnapshotDTO?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            snapshot = try await apiClient.fetchDashboardSnapshot()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
 }
