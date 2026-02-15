# Sagebrush iOS App Testing

This directory contains unit tests for the Sagebrush iOS application. These tests verify the
core functionality of the iOS client, including API communication, authentication, and keychain
operations.

## Test Coverage

### 1. AdminAPIClient Tests (10 tests)

**File**: `AdminAPIClientTests.swift`

Tests the HTTP client that communicates with the Bazaar backend:
- ✅ Endpoint URL construction
- ✅ API error descriptions (unauthorized, forbidden, server errors)
- ✅ JSON decoding (PersonResponse, QuestionResponse with/without choices)
- ✅ JSON encoding (CreatePersonRequest, UpdatePersonRequest, UpdateQuestionRequest)
- ✅ Empty response handling
- ✅ Special characters and unicode handling

### 2. AuthenticationManager Tests (20 tests)

**File**: `AuthenticationManagerTests.swift`

Tests the RBAC (Role-Based Access Control) logic:
- ✅ Admin role determination from Cognito groups
- ✅ Case insensitivity (admin, Admin, ADMINS, AdMiNs)
- ✅ Whitespace handling in group names
- ✅ Empty/nil groups defaulting to customer role
- ✅ Admin precedence in multiple groups
- ✅ Property consistency (isAdmin, isCustomer, currentRole)
- ✅ Server-side logic matching verification
- ✅ Thread safety with @MainActor

### 3. KeychainService Tests (29 tests)

**File**: `KeychainServiceTests.swift`

Tests secure token storage and retrieval:
- ✅ Save and load access/ID/refresh tokens
- ✅ Multiple tokens independently
- ✅ Overwriting existing values
- ✅ Date save/load for token expiration
- ✅ Individual and bulk deletion
- ✅ Error handling for missing items
- ✅ Token validity checking (>5 minutes remaining)
- ✅ Boundary cases (exactly 5 minutes, 5 min + 1 sec)
- ✅ Special characters, long tokens, unicode support

## Running the Tests

### Option 1: Xcode (Recommended)

Since these are iOS-specific tests, they should be run in Xcode with the iOS simulator:

```bash
cd /Users/fbettag/src/Luxe/SagebrushApp
open Sagebrush.xcodeproj
```

Then in Xcode:
1. Select **Product** → **Test** (⌘U)
2. Or click the diamond icon next to any test function

### Option 2: xcodebuild (Command Line)

```bash
cd /Users/fbettag/src/Luxe/SagebrushApp
xcodebuild test \
  -project Sagebrush.xcodeproj \
  -scheme Sagebrush \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Why Not `swift test`?

The `swift test` command runs on macOS, but the Sagebrush app uses iOS-only SwiftUI modifiers
(`.insetGrouped`, `.navigationBarTrailing`, `.page`) that aren't available on macOS. Therefore,
SPM tests won't work for iOS-specific code.

## Integration with Backend

These unit tests verify the iOS client in isolation. For full integration testing:

1. **Backend API Tests** (in `Tests/BazaarTests/`):
   - `AuthenticatedPeopleAdminTests.swift` - 12 tests for People API
   - `AuthenticatedQuestionAdminTests.swift` - 6 tests for Questions API

2. **Contract Verification**:
   - Backend tests verify API endpoints work correctly
   - iOS tests verify client formats requests/responses correctly
   - Together they ensure the contract between client and server

## Test Philosophy

Following the project's TDD (Test-Driven Development) principles:

1. ✅ Tests written BEFORE implementing RBAC features
2. ✅ Swift Testing framework (not XCTest)
3. ✅ Comprehensive coverage of edge cases
4. ✅ Tests serve as documentation of behavior
5. ✅ All tests must pass before release

## CI/CD Integration

For continuous integration, these tests should be run as part of the iOS app build:

```yaml
# Example GitHub Actions workflow
- name: Run iOS Tests
  run: |
    cd SagebrushApp
    xcodebuild test \
      -project Sagebrush.xcodeproj \
      -scheme Sagebrush \
      -sdk iphonesimulator \
      -destination 'platform=iOS Simulator,name=iPhone 17' \
      -enableCodeCoverage YES
```

## Future Testing

### Integration Tests (Planned)

Create tests that:
1. Start a real Bazaar test server
2. Use AdminAPIClient to make actual HTTP requests
3. Verify end-to-end authentication flow
4. Test real JWT token parsing and validation

### UI Tests (Planned)

Use XCUITest to verify:
1. Admin dashboard navigation
2. People and Questions list views
3. Role-based UI visibility (admin vs customer views)
4. Form validation and error handling

## Test Data

All tests use:
- In-memory databases (no persistence between tests)
- Mock authentication with test JWTs
- Isolated test instances (no shared state)
- Deterministic test data (no randomness)

## Troubleshooting

### Tests Fail Due to Keychain Access

If keychain tests fail, ensure:
- Keychain access is enabled in test host
- Running on simulator (not real device during development)
- No leftover data from previous test runs

### Authentication Tests Fail

Verify:
- Test groups match expected format (["admins"], ["staff"], [])
- Case handling is consistent
- @MainActor isolation is respected

### API Tests Fail

Check:
- JSON encoding/decoding matches backend DTOs
- Date formatting uses ISO8601
- Snake case ↔ camel case conversion works

## Related Documentation

- `/Sources/Bazaar/README.md` - Backend API documentation
- `/Tests/BazaarTests/README.md` - Backend testing guide
- `/SagebrushApp/README.md` - iOS app architecture
- `/.claude/CLAUDE.md` - Full-stack testing principles
