import Dali
import SwiftUI

/// View modifier that only shows content if user has admin role
struct AdminOnlyModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthenticationManager

    func body(content: Content) -> some View {
        if authManager.isAdmin {
            content
        } else {
            EmptyView()
        }
    }
}

/// View modifier that only shows content if user has a specific role
struct RoleRequirementModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthenticationManager
    let requiredRole: UserRole

    func body(content: Content) -> some View {
        if authManager.currentRole == requiredRole {
            content
        } else {
            EmptyView()
        }
    }
}

extension View {
    /// Only show this view if the user is an admin
    func adminOnly() -> some View {
        modifier(AdminOnlyModifier())
    }

    /// Only show this view if the user has the specified role
    func requireRole(_ role: UserRole) -> some View {
        modifier(RoleRequirementModifier(requiredRole: role))
    }
}
