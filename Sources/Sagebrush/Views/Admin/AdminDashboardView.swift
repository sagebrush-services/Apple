import SwiftUI
import Dali

struct AdminDashboardView: View {
    @EnvironmentObject var authManager: AuthenticationManager

    var body: some View {
        List {
            Section("Management") {
                NavigationLink(destination: PeopleListView()) {
                    Label("People", systemImage: "person.2.fill")
                        .foregroundColor(Color("SagebrushGreen"))
                }

                NavigationLink(destination: QuestionsListView()) {
                    Label("Questions", systemImage: "questionmark.circle.fill")
                        .foregroundColor(Color("SagebrushGreen"))
                }
            }

            Section("Account") {
                HStack {
                    Text("Role")
                    Spacer()
                    Text(authManager.currentRole.rawValue.capitalized)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Email")
                    Spacer()
                    Text(authManager.userEmail ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Admin Panel")
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
#endif
    }
}
