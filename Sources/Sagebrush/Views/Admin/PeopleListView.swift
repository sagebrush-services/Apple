import Dali
import SwiftUI

struct PeopleListView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var apiClient: AdminAPIClient
    @State private var people: [Person] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""

    init() {
        _apiClient = StateObject(
            wrappedValue: AdminAPIClient(
                baseURL: URL(string: Config.environment.apiBaseURL)!,
                authManager: AuthenticationManager.shared
            )
        )
    }

    var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        } else {
            return people.filter { person in
                person.email.lowercased().contains(searchText.lowercased())
                    || person.name.lowercased().contains(searchText.lowercased())
            }
        }
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if filteredPeople.isEmpty {
                Text("No people found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(filteredPeople, id: \.id) { person in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(person.name)
                            .font(.headline)

                        Text(person.email)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let insertedAt = person.insertedAt {
                            Text("Member since: \(insertedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("People")
        .searchable(text: $searchText, prompt: "Search by name or email")
        .refreshable {
            await loadPeople()
        }
        .task {
            await loadPeople()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadPeople() async {
        isLoading = true
        errorMessage = nil

        do {
            people = try await apiClient.fetchPeople()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
