#if os(iOS)
import SwiftUI

struct FormationDashboardView: View {
    @StateObject private var store = FormationStore.shared
    @State private var navigationPath: [UUID] = []
    @State private var isPresentingError = false
    @State private var loadingNotationCode: String?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                if !store.instances.isEmpty {
                    Section("Active Formations") {
                        ForEach(store.instances, id: \.id) { instance in
                            NavigationLink(value: instance.id) {
                                FormationInstanceRow(instance: instance)
                            }
                        }
                    }
                }

                Section("Start New Formation") {
                    ForEach(store.notations) { notation in
                        Button {
                            guard loadingNotationCode == nil else { return }
                            loadingNotationCode = notation.code
                            Task {
                                await startFormation(notation)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(notation.title)
                                        .font(.headline)
                                    if let description = notation.description {
                                        Text(description)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if loadingNotationCode == notation.code {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .scaleEffect(0.8)
                                        .foregroundColor(.secondary)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .disabled(loadingNotationCode != nil)
                    }
                }
            }
            .navigationTitle("Formations")
            .navigationDestination(for: UUID.self) { instanceID in
                FormationFlowView(instanceID: instanceID)
            }
            .refreshable {
                await refreshAll()
            }
            .task {
                await refreshAll()
            }
            .alert(
                "Error",
                isPresented: $isPresentingError,
                actions: {
                    Button("OK", role: .cancel) {}
                },
                message: {
                    Text(store.errorMessage ?? "Unknown error")
                }
            )
        }
    }

    private func refreshAll() async {
        await store.refreshNotations()
        await store.refreshInstances()
        isPresentingError = store.errorMessage != nil
    }

    @MainActor
    private func startFormation(_ notation: NotationSummaryDTO) async {
        defer { loadingNotationCode = nil }
        do {
            let instance = try await store.createInstance(for: notation)
            navigationPath.append(instance.id)
        } catch {
            store.errorMessage = error.localizedDescription
            isPresentingError = true
        }
    }
}

private struct FormationInstanceRow: View {
    let instance: FlowInstanceResponseDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(instance.notationCode.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.headline)

            if let percent = instance.progressPercent {
                ProgressView(value: percent, total: 1.0)
                    .progressViewStyle(.linear)
                Text(label(for: percent))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(instance.isCompleted ? "Completed" : "In Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func label(for percent: Double) -> String {
        let clamped = max(0.0, min(1.0, percent))
        let formatted = Int(clamped * 100)
        return "Progress: \(formatted)%"
    }
}
#endif
