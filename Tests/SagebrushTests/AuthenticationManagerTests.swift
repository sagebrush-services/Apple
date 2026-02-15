import Dali
import Foundation
import Testing

@testable import Sagebrush

@Suite("AuthenticationManager Tests", .serialized)
struct AuthenticationManagerTests {

    // MARK: - Role Determination Tests

    @Test("Role determination: admin group returns admin role")
    @MainActor
    func testAdminRoleDetermination() {
        let authManager = AuthenticationManager.shared

        // Simulate admin groups
        let testGroups = ["admins"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .admin)
        #expect(authManager.isAdmin == true)
        #expect(authManager.isCustomer == false)
    }

    @Test("Role determination: Admin (capitalized) group returns admin role")
    @MainActor
    func testAdminRoleCaseSensitivity() {
        let authManager = AuthenticationManager.shared

        // Test case insensitivity
        let testGroups = ["Admin"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .admin)
        #expect(authManager.isAdmin == true)
    }

    @Test("Role determination: ADMINS (uppercase) group returns admin role")
    @MainActor
    func testAdminRoleUppercase() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["ADMINS"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .admin)
        #expect(authManager.isAdmin == true)
    }

    @Test("Role determination: admin with spaces returns admin role")
    @MainActor
    func testAdminRoleWithSpaces() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["  admin  "]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .admin)
        #expect(authManager.isAdmin == true)
    }

    @Test("Role determination: empty groups returns customer role")
    @MainActor
    func testEmptyGroupsReturnsCustomer() {
        let authManager = AuthenticationManager.shared

        let testGroups: [String] = []
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .customer)
        #expect(authManager.isAdmin == false)
        #expect(authManager.isCustomer == true)
    }

    @Test("Role determination: nil groups returns customer role")
    @MainActor
    func testNilGroupsReturnsCustomer() {
        let authManager = AuthenticationManager.shared

        authManager.userGroups = nil

        #expect(authManager.currentRole == .customer)
        #expect(authManager.isAdmin == false)
        #expect(authManager.isCustomer == true)
    }

    @Test("Role determination: staff group returns customer role (staff not used)")
    @MainActor
    func testStaffGroupReturnsCustomer() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["staff"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .customer)
        #expect(authManager.isAdmin == false)
        #expect(authManager.isCustomer == true)
    }

    @Test("Role determination: random group returns customer role")
    @MainActor
    func testRandomGroupReturnsCustomer() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["random_group", "another_group"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .customer)
        #expect(authManager.isAdmin == false)
        #expect(authManager.isCustomer == true)
    }

    @Test("Role determination: admin takes precedence in multiple groups")
    @MainActor
    func testAdminPrecedenceInMultipleGroups() {
        let authManager = AuthenticationManager.shared

        // Admin should take precedence even with other groups
        let testGroups = ["staff", "customer", "admins", "other"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .admin)
        #expect(authManager.isAdmin == true)
    }

    @Test("Role determination: admin in middle of groups array")
    @MainActor
    func testAdminInMiddleOfGroups() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["group1", "group2", "admin", "group3"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .admin)
        #expect(authManager.isAdmin == true)
    }

    // MARK: - Role Property Tests

    @Test("isAdmin property returns correct boolean")
    @MainActor
    func testIsAdminProperty() {
        let authManager = AuthenticationManager.shared

        authManager.userGroups = ["admins"]
        #expect(authManager.isAdmin == true)

        authManager.userGroups = ["customer"]
        #expect(authManager.isAdmin == false)

        authManager.userGroups = nil
        #expect(authManager.isAdmin == false)
    }

    @Test("isCustomer property returns correct boolean")
    @MainActor
    func testIsCustomerProperty() {
        let authManager = AuthenticationManager.shared

        authManager.userGroups = nil
        #expect(authManager.isCustomer == true)

        authManager.userGroups = ["random_group"]
        #expect(authManager.isCustomer == true)

        authManager.userGroups = ["admins"]
        #expect(authManager.isCustomer == false)
    }

    @Test("currentRole property returns UserRole enum")
    @MainActor
    func testCurrentRoleProperty() {
        let authManager = AuthenticationManager.shared

        authManager.userGroups = ["admins"]
        #expect(authManager.currentRole == UserRole.admin)

        authManager.userGroups = []
        #expect(authManager.currentRole == UserRole.customer)
    }

    // MARK: - Edge Case Tests

    @Test("Role determination handles groups with mixed case")
    @MainActor
    func testMixedCaseGroupNames() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["AdMiNs"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .admin)
        #expect(authManager.isAdmin == true)
    }

    @Test("Role determination handles groups with extra whitespace")
    @MainActor
    func testGroupsWithExtraWhitespace() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["   admins   ", "  group2  "]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .admin)
        #expect(authManager.isAdmin == true)
    }

    @Test("Role determination handles empty string in groups")
    @MainActor
    func testEmptyStringInGroups() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["", "staff", ""]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .customer)
        #expect(authManager.isAdmin == false)
    }

    @Test("Role determination handles whitespace-only strings")
    @MainActor
    func testWhitespaceOnlyGroups() {
        let authManager = AuthenticationManager.shared

        let testGroups = ["   ", "\t", "\n"]
        authManager.userGroups = testGroups

        #expect(authManager.currentRole == .customer)
        #expect(authManager.isAdmin == false)
    }

    // MARK: - Consistency Tests

    @Test("Role properties are consistent with each other")
    @MainActor
    func testRolePropertiesConsistency() {
        let authManager = AuthenticationManager.shared

        // When admin
        authManager.userGroups = ["admins"]
        #expect(authManager.isAdmin == true)
        #expect(authManager.isCustomer == false)
        #expect(authManager.currentRole == .admin)

        // When customer
        authManager.userGroups = []
        #expect(authManager.isAdmin == false)
        #expect(authManager.isCustomer == true)
        #expect(authManager.currentRole == .customer)
    }

    @Test("Role determination matches server-side logic")
    @MainActor
    func testRoleDeterminationMatchesServerLogic() {
        let authManager = AuthenticationManager.shared

        // This test verifies that the iOS role determination
        // matches the server's AuthenticationMiddleware.determineUserRole()

        // Server checks for "admin" or "admins" (case-insensitive, trimmed)
        let adminVariants = ["admin", "admins", "ADMIN", "ADMINS", "Admin", "Admins", " admin ", " admins "]

        for variant in adminVariants {
            authManager.userGroups = [variant]
            #expect(authManager.currentRole == .admin, "Failed for variant: \(variant)")
        }

        // Server defaults to customer for anything else
        let nonAdminGroups = ["staff", "customer", "user", "guest", ""]

        for group in nonAdminGroups {
            authManager.userGroups = [group]
            #expect(authManager.currentRole == .customer, "Failed for group: \(group)")
        }
    }

    // MARK: - Thread Safety Tests

    @Test("Role computation is thread-safe on MainActor")
    @MainActor
    func testRoleComputationThreadSafety() async {
        let authManager = AuthenticationManager.shared

        // Reset state first to ensure test isolation
        authManager.userGroups = nil

        // Set groups and verify multiple reads are consistent
        authManager.userGroups = ["admins"]

        let results = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    authManager.isAdmin
                }
            }

            var allResults: [Bool] = []
            for await result in group {
                allResults.append(result)
            }
            return allResults
        }

        // All results should be consistently true
        #expect(results.allSatisfy { $0 == true })
        #expect(results.count == 10)
    }
}
