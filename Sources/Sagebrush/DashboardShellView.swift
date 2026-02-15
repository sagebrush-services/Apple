import SwiftUI

enum DashboardSection: String, CaseIterable, Identifiable {
    case overview
    case formations
    case mailroom
    case entities
    case admin

    var id: String { rawValue }

    var label: String {
        switch self {
        case .overview: return "Overview"
        case .formations: return "Formations"
        case .mailroom: return "Mailroom"
        case .entities: return "Entities"
        case .admin: return "Admin"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: return "rectangle.grid.2x2.fill"
        case .formations: return "building.2"
        case .mailroom: return "envelope.badge"
        case .entities: return "person.3"
        case .admin: return "gearshape.2"
        }
    }
}

struct DashboardShellView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var dashboardModel = DashboardViewModel()
    @State private var selectedSection: DashboardSection = .overview

    private var isRegularSizeClass: Bool {
        #if os(iOS)
        UIScreen.main.bounds.width >= 768
        #else
        true
        #endif
    }

    var body: some View {
        Group {
            if isRegularSizeClass {
                NavigationSplitView {
                    #if os(iOS)
                    List {
                        ForEach(DashboardSection.allCases) { section in
                            Button {
                                selectedSection = section
                            } label: {
                                sidebarLabel(for: section)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                selectedSection == section ? Color.accentColor.opacity(0.15) : Color.clear
                            )
                        }
                    }
                    .navigationTitle("Sagebrush")
                    #else
                    List(DashboardSection.allCases, selection: $selectedSection) { section in
                        sidebarLabel(for: section)
                            .padding(.vertical, 6)
                    }
                    .navigationTitle("Sagebrush")
                    #endif
                } detail: {
                    NavigationStack {
                        detailContent
                    }
                }
            } else {
                NavigationStack {
                    detailContent
                        .navigationTitle(selectedSection.label)
                        #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .principal) {
                                Menu {
                                    Picker("Section", selection: $selectedSection) {
                                        ForEach(DashboardSection.allCases) { section in
                                            Label(section.label, systemImage: section.symbolName)
                                                .tag(section)
                                        }
                                    }
                                } label: {
                                    Label(selectedSection.label, systemImage: selectedSection.symbolName)
                                        .labelStyle(.titleAndIcon)
                                }
                            }
                        }
                }
            }
        }
        .task {
            await dashboardModel.refresh()
        }
        .environmentObject(dashboardModel)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selectedSection {
        case .overview:
            DashboardOverviewView(selectedSection: $selectedSection)
        case .formations:
            #if os(iOS)
            FormationDashboardView()
            #else
            Text("Formation management is available on iOS devices.")
                .foregroundColor(.secondary)
                .padding()
            #endif
        case .mailroom:
            MailroomOverviewView()
        case .entities:
            EntitiesOverviewView()
        case .admin:
            AdminDashboardContainer()
        }
    }
}

extension DashboardShellView {
    @ViewBuilder
    fileprivate func sidebarLabel(for section: DashboardSection) -> some View {
        Label {
            Text(section.label)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: section.symbolName)
                .symbolRenderingMode(.monochrome)
                .imageScale(.medium)
                .frame(width: 24, height: 24)
        }
        .labelStyle(.titleAndIcon)
    }
}
