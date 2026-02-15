#if os(iOS)
import SwiftUI
import NotationEngine

struct FormationFlowView: View {
    let instanceID: UUID

    @StateObject private var store = FormationStore.shared
    @State private var instance: FlowInstanceResponseDTO?
    @State private var descriptor: QuestionStepDescriptor?

    @State private var textInput: String = ""
    @State private var selectedChoice: String?
    @State private var selectedMultiChoices: Set<String> = []
    @State private var selectedAgentOption: String = "neon-law"
    @State private var customAgentName: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let instance {
                content(for: instance)
            } else {
                ProgressView()
                    .task {
                        await loadInstance()
                    }
            }
        }
        .navigationTitle("Formation")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .task(id: instanceID) {
            await loadInstance()
        }
    }

    @ViewBuilder
    private func content(for instance: FlowInstanceResponseDTO) -> some View {
        VStack(spacing: 20) {
            progressHeader(for: instance)

            if instance.isCompleted {
                completionView
            } else if let descriptor {
                questionCard(descriptor: descriptor)
            } else {
                Text("Fetching next step...")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    private func progressHeader(for instance: FlowInstanceResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(instance.notationCode.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                let percent = instance.progressPercent ?? (instance.isCompleted ? 1.0 : 0.0)
                Text("\(Int(percent * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            }

            let percent = instance.progressPercent ?? (instance.isCompleted ? 1.0 : 0.0)
            ProgressView(value: percent, total: 1.0)
                .progressViewStyle(.linear)

            HStack(spacing: 4) {
                Text("Current Stage:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(formatStageLabel(instance.progressStage ?? (instance.isCompleted ? "completed" : "in-progress")))
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
            }
        }
    }

    /// Formats stage labels like "entity-name" to "Entity Name"
    private func formatStageLabel(_ label: String) -> String {
        label
            .split(separator: "-")
            .map { String($0).capitalized }
            .joined(separator: " ")
    }

    private func questionCard(descriptor: QuestionStepDescriptor) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(descriptor.displayPrompt)
                .font(.headline)

            if let help = descriptor.displayHelp {
                Text(help)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            inputView(for: descriptor.component)

            Button {
                Task { await submitAnswer(descriptor: descriptor) }
            } label: {
                HStack {
                    if isSubmitting { ProgressView() }
                    Text(isSubmitting ? "Submitting" : "Continue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func inputView(for component: QuestionStepDescriptor.Component) -> some View {
        switch component {
        case .singleLineText:
            TextField("Enter response", text: $textInput)
                .textFieldStyle(.roundedBorder)
        case .multiLineText:
            TextEditor(text: $textInput)
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2)))
        case .radio(let choices), .picker(let choices):
            VStack(alignment: .leading, spacing: 12) {
                ForEach(choices, id: \.value) { choice in
                    Button {
                        selectedChoice = choice.value
                    } label: {
                        HStack {
                            Image(systemName: selectedChoice == choice.value ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(.accentColor)
                            Text(choice.label)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        case .multiSelect(let choices):
            VStack(alignment: .leading, spacing: 12) {
                Text("Select all that apply")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                ForEach(choices, id: \.value) { choice in
                    Button {
                        toggleMultiSelect(choice.value)
                    } label: {
                        HStack {
                            Image(
                                systemName: selectedMultiChoices.contains(choice.value)
                                    ? "checkmark.square.fill" : "square"
                            )
                            .foregroundColor(.accentColor)
                            Text(choice.label)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel(Text(choice.label))
                    .accessibilityAddTraits(selectedMultiChoices.contains(choice.value) ? [.isSelected] : [])
                }
            }
        case .toggle:
            Toggle(
                isOn: Binding(
                    get: {
                        selectedChoice == "yes"
                    },
                    set: { newValue in
                        selectedChoice = newValue ? "yes" : "no"
                    }
                )
            ) {
                Text("Yes / No")
            }
            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
        case .date:
            DatePicker(
                "",
                selection: Binding(
                    get: {
                        let formatter = ISO8601DateFormatter()
                        if let stored = selectedChoice, let date = formatter.date(from: stored) {
                            return date
                        }
                        return Date()
                    },
                    set: { date in
                        let formatter = ISO8601DateFormatter()
                        selectedChoice = formatter.string(from: date)
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
        case .registeredAgent:
            registeredAgentInput
        case .organizationLookup:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Enter organization name", text: $textInput)
                    .textFieldStyle(.roundedBorder)
                Text("We'll match this to your entity records during staff review.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        default:
            Text("This step currently requires staff assistance. We'll notify you once it's handled.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }

    private var registeredAgentInput: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(RegisteredAgentOption.defaultOptions, id: \.identifier) { option in
                Button {
                    selectedAgentOption = option.identifier
                } label: {
                    HStack {
                        Image(
                            systemName: selectedAgentOption == option.identifier ? "largecircle.fill.circle" : "circle"
                        )
                        .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text(option.label)
                            if let subtitle = option.subtitle {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if selectedAgentOption == "custom" {
                TextField("Registered agent name", text: $customAgentName)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var completionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("All steps complete")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Our team is finalizing your paperwork. We'll notify you as soon as filing is confirmed.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func loadInstance() async {
        do {
            let response = try await store.loadInstance(id: instanceID)
            instance = response
            descriptor = store.descriptor(for: response)
            resetInputs(for: descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitAnswer(descriptor: QuestionStepDescriptor) async {
        guard let instance else { return }

        do {
            isSubmitting = true
            let answer = try buildAnswer(for: descriptor.component)
            let updated = try await store.submitAnswer(answer, for: instance)
            self.instance = updated
            self.descriptor = store.descriptor(for: updated)
            resetInputs(for: self.descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    private func buildAnswer(
        for component: QuestionStepDescriptor.Component
    ) throws -> NotationEngine.FlowInstance.AnswerValue {
        switch component {
        case .singleLineText, .multiLineText, .organizationLookup:
            guard !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.missingInput
            }
            if case .organizationLookup = component {
                return .metadata(["entity_name": textInput])
            }
            return .string(textInput)
        case .radio, .picker, .toggle, .date, .dateTime:
            guard let choice = selectedChoice else { throw ValidationError.missingSelection }
            return .choice(choice)
        case .multiSelect(let choices):
            let ordered = choices.map(\.value).filter { selectedMultiChoices.contains($0) }
            return .multiChoice(ordered)
        case .registeredAgent:
            if selectedAgentOption == "custom" {
                guard !customAgentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw ValidationError.missingInput
                }
                return .metadata([
                    "agent_type": "custom",
                    "agent_name": customAgentName,
                ])
            }
            guard let metadata = RegisteredAgentOption.metadata(for: selectedAgentOption) else {
                throw ValidationError.missingSelection
            }
            return .metadata(metadata)
        default:
            throw ValidationError.unsupported
        }
    }

    private func resetInputs(for descriptor: QuestionStepDescriptor?) {
        textInput = ""
        selectedChoice = nil
        selectedMultiChoices.removeAll()
        selectedAgentOption = "neon-law"
        customAgentName = ""

        guard let descriptor else { return }

        switch descriptor.component {
        case .radio(let choices), .picker(let choices):
            selectedChoice = choices.first?.value
        case .toggle:
            selectedChoice = "yes"
        default:
            break
        }
    }

    private func toggleMultiSelect(_ value: String) {
        if selectedMultiChoices.contains(value) {
            selectedMultiChoices.remove(value)
        } else {
            selectedMultiChoices.insert(value)
        }
    }

    private enum ValidationError: LocalizedError {
        case missingInput
        case missingSelection
        case unsupported

        var errorDescription: String? {
            switch self {
            case .missingInput:
                return "Please provide an answer before continuing."
            case .missingSelection:
                return "Select an option to proceed."
            case .unsupported:
                return "This step currently requires staff assistance."
            }
        }
    }
}
#endif

private struct RegisteredAgentOption {
    let identifier: String
    let label: String
    let subtitle: String?
    let metadata: [String: String]

    static let defaultOptions: [RegisteredAgentOption] = [
        RegisteredAgentOption(
            identifier: "neon-law",
            label: "Use Neon Law as Registered Agent",
            subtitle: "We'll handle filings and compliance.",
            metadata: [
                "agent_type": "neon_law",
                "agent_name": "Neon Law",
                "agent_email": "support@sagebrush.services",
            ]
        ),
        RegisteredAgentOption(
            identifier: "custom",
            label: "Provide a different registered agent",
            subtitle: "Enter details manually",
            metadata: [:]
        ),
    ]

    static func metadata(for identifier: String) -> [String: String]? {
        defaultOptions.first(where: { $0.identifier == identifier })?.metadata
    }
}
