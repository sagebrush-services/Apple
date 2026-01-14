import SwiftUI
import Dali

struct QuestionsListView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var apiClient: AdminAPIClient
    @State private var questions: [Question] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    init() {
        _apiClient = StateObject(wrappedValue: AdminAPIClient(
            baseURL: URL(string: Config.environment.apiBaseURL)!,
            authManager: AuthenticationManager.shared
        ))
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if questions.isEmpty {
                Text("No questions found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(questions, id: \.id) { question in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question.prompt)
                            .font(.headline)
                            .foregroundColor(.primary)

                        HStack {
                            Text("Code: \(question.code)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(question.questionType.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }

                        if let helpText = question.helpText {
                            Text(helpText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        HStack {
                            if let insertedAt = question.insertedAt {
                                Text("Created: \(insertedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if let updatedAt = question.updatedAt {
                                Text("Updated: \(updatedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteQuestions)
            }
        }
        .navigationTitle("Questions")
#if os(iOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    // TODO: Show create question sheet
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
#endif
        .refreshable {
            await loadQuestions()
        }
        .task {
            await loadQuestions()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadQuestions() async {
        isLoading = true
        errorMessage = nil

        do {
            questions = try await apiClient.fetchQuestions()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func deleteQuestions(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let question = questions[index]
                guard let id = question.id else { continue }

                do {
                    try await apiClient.deleteQuestion(id: id)
                    questions.remove(at: index)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
