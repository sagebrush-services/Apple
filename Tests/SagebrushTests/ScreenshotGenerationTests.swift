#if os(macOS)
import AppKit
import Foundation
import NotationEngine
import SwiftUI
import Testing

@testable import Sagebrush

@MainActor
@Suite("ScreenshotGenerationTests")
struct ScreenshotGenerationTests {
    @MainActor
    @Test("Generate iOS screenshot set and review HTML")
    func generateIOSScreenshots() async throws {
        let outputDirectory = Self.outputDirectory()
        try Self.prepareDirectory(outputDirectory)

        let auth = AuthenticationManager.shared
        let onboarding = OnboardingManager.shared
        onboarding.hasSeenWelcome = true

        // 00 - Login
        do {
            try await auth.signOut()
        } catch {
            // Best-effort auth reset for deterministic screenshot runs.
        }
        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    LoginView()
                        .environmentObject(auth)
                        .environmentObject(onboarding)
                }
            },
            name: "00-login",
            outputDirectory: outputDirectory,
            settleFor: 0.6
        )

        // Remaining screens in authenticated demo mode.
        auth.isAuthenticated = true
        auth.userEmail = "demo@sagebrush.services"
        auth.userGivenName = "Demo"
        auth.userGroups = ["admin"]

        let snapshot = await DemoBackend.shared.fetchDashboardSnapshot()
        let dashboardViewModel = DashboardViewModel()
        dashboardViewModel.snapshot = snapshot
        dashboardViewModel.isLoading = false
        dashboardViewModel.errorMessage = nil

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    DashboardOverviewView(selectedSection: .constant(.overview))
                        .environmentObject(auth)
                        .environmentObject(dashboardViewModel)
                }
            },
            name: "01-dashboard-overview",
            outputDirectory: outputDirectory
        )

        #if os(iOS)
        let formationStore = FormationStore.shared
        await formationStore.refreshNotations()
        await formationStore.refreshInstances()

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    FormationDashboardView()
                }
            },
            name: "02-formations",
            outputDirectory: outputDirectory,
            settleFor: 1.2
        )

        let notation = try await Self.requireFirstNotation()
        var flowInstance = try await formationStore.createInstance(for: notation)

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    FormationFlowView(
                        instanceID: flowInstance.id
                    )
                }
            },
            name: "03-formation-flow-step",
            outputDirectory: outputDirectory,
            settleFor: 0.8
        )

        // Walk the flow to completion using deterministic dummy answers.
        var guardCounter = 0
        while !flowInstance.isCompleted && guardCounter < 24 {
            guardCounter += 1
            guard let descriptor = formationStore.descriptor(for: flowInstance) else { break }
            let answer = Self.answer(for: descriptor.component)
            flowInstance = try await formationStore.submitAnswer(answer, for: flowInstance)
        }

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    FormationFlowView(
                        instanceID: flowInstance.id
                    )
                }
            },
            name: "04-formation-flow-completed",
            outputDirectory: outputDirectory,
            settleFor: 0.8
        )
        #else
        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    DashboardOverviewView(selectedSection: .constant(.formations))
                        .environmentObject(dashboardViewModel)
                        .environmentObject(auth)
                }
            },
            name: "02-formations",
            outputDirectory: outputDirectory,
            settleFor: 1.2
        )
        #endif

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    MailroomOverviewView()
                        .environmentObject(dashboardViewModel)
                }
            },
            name: "05-mailroom",
            outputDirectory: outputDirectory
        )

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    EntitiesOverviewView()
                }
            },
            name: "06-entities",
            outputDirectory: outputDirectory
        )

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    AdminDashboardView()
                        .environmentObject(auth)
                }
            },
            name: "07-admin-dashboard",
            outputDirectory: outputDirectory,
            settleFor: 1.2
        )

        let demoPeople = await DemoBackend.shared.fetchPeople()
        let demoQuestions = await DemoBackend.shared.fetchQuestions()

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    PeopleListView(preloaded: demoPeople)
                        .environmentObject(auth)
                }
            },
            name: "08-admin-people",
            outputDirectory: outputDirectory,
            settleFor: 0.6
        )

        try await Self.captureForAllDevices(
            {
                NavigationStack {
                    QuestionsListView(preloaded: demoQuestions)
                        .environmentObject(auth)
                }
            },
            name: "09-admin-questions",
            outputDirectory: outputDirectory,
            settleFor: 0.6
        )

        try Self.writeReviewHTML(in: outputDirectory)
    }
}

extension ScreenshotGenerationTests {
    fileprivate struct ScreenshotDevice {
        let name: String
        let folder: String
        let size: CGSize
    }

    fileprivate static let screenshotDevices: [ScreenshotDevice] = [
        ScreenshotDevice(
            name: "iPhone",
            folder: "iphone",
            size: CGSize(width: 430, height: 932)
        ),
        ScreenshotDevice(
            name: "iPad",
            folder: "ipad",
            size: CGSize(width: 1024, height: 1366)
        ),
    ]

    fileprivate static func outputDirectory() -> URL {
        if let custom = ProcessInfo.processInfo.environment["SAGEBRUSH_SCREENSHOT_OUTPUT_DIR"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("artifacts", isDirectory: true)
            .appendingPathComponent("ios-screenshots", isDirectory: true)
    }

    fileprivate static func prepareDirectory(_ directory: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: directory.path) {
            try fm.removeItem(at: directory)
        }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)

        for device in screenshotDevices {
            let target = directory.appendingPathComponent(device.folder, isDirectory: true)
            try fm.createDirectory(at: target, withIntermediateDirectories: true)
        }
    }

    @MainActor
    fileprivate static func captureForAllDevices<V: View>(
        _ viewBuilder: () -> V,
        name: String,
        outputDirectory: URL,
        settleFor: TimeInterval = 0.6
    ) async throws {
        for device in screenshotDevices {
            try await capture(
                viewBuilder(),
                name: name,
                outputDirectory: outputDirectory,
                device: device,
                settleFor: settleFor
            )
        }
    }

    @MainActor
    fileprivate static func capture<V: View>(
        _ view: V,
        name: String,
        outputDirectory: URL,
        device: ScreenshotDevice,
        settleFor: TimeInterval
    ) async throws {
        let content =
            view
            .frame(width: device.size.width, height: device.size.height, alignment: .topLeading)
            .background(Color.white)
            .environment(\.colorScheme, .light)

        let rect = CGRect(origin: .zero, size: device.size)
        let hosting = NSHostingView(rootView: content)
        hosting.frame = rect

        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.backgroundColor = .white
        window.isOpaque = true
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)

        Self.pumpMainRunLoop(for: settleFor)

        hosting.layoutSubtreeIfNeeded()
        hosting.displayIfNeeded()

        guard let bitmap = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            window.orderOut(nil)
            throw ScreenshotError.renderFailed("Unable to allocate bitmap rep for \(name) (\(device.name))")
        }

        hosting.cacheDisplay(in: hosting.bounds, to: bitmap)
        window.orderOut(nil)

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotError.renderFailed("Unable to encode PNG for \(name) (\(device.name))")
        }

        let target =
            outputDirectory
            .appendingPathComponent(device.folder, isDirectory: true)
            .appendingPathComponent("\(name).png")
        try data.write(to: target, options: .atomic)
    }

    @MainActor
    fileprivate static func pumpMainRunLoop(for seconds: TimeInterval) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
    }

    fileprivate static func writeReviewHTML(in outputDirectory: URL) throws {
        let fm = FileManager.default
        let iphoneDir = outputDirectory.appendingPathComponent("iphone", isDirectory: true)
        let ipadDir = outputDirectory.appendingPathComponent("ipad", isDirectory: true)

        let iphonePNGs = try fm.contentsOfDirectory(at: iphoneDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let ipadPNGs = try fm.contentsOfDirectory(at: ipadDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "png" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        let imageNames = Array(Set(iphonePNGs.map(\.lastPathComponent) + ipadPNGs.map(\.lastPathComponent))).sorted()

        let rows = imageNames.map { name in
            let iphonePath = iphoneDir.appendingPathComponent(name).path
            let ipadPath = ipadDir.appendingPathComponent(name).path

            let iphoneCell =
                fm.fileExists(atPath: iphonePath)
                ? "<img src=\"./iphone/\(name)\" alt=\"\(name) iPhone\" />"
                : "<div class=\"missing\">Missing iPhone capture</div>"
            let ipadCell =
                fm.fileExists(atPath: ipadPath)
                ? "<img src=\"./ipad/\(name)\" alt=\"\(name) iPad\" />"
                : "<div class=\"missing\">Missing iPad capture</div>"

            return "<section class=\"row\">\n"
                + "  <h2>" + name + "</h2>\n"
                + "  <div class=\"grid\">\n"
                + "    <article class=\"card\">\n"
                + "      <h3>iPhone</h3>\n"
                + "      " + iphoneCell + "\n"
                + "    </article>\n"
                + "    <article class=\"card\">\n"
                + "      <h3>iPad</h3>\n"
                + "      " + ipadCell + "\n"
                + "    </article>\n"
                + "  </div>\n"
                + "</section>\n"
        }.joined(separator: "\n")

        let html = """
            <!doctype html>
            <html lang="en">
            <head>
              <meta charset="utf-8" />
              <meta name="viewport" content="width=device-width, initial-scale=1" />
              <title>Sagebrush iOS Screenshot Review</title>
              <style>
                :root { color-scheme: light; }
                body {
                  margin: 0;
                  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                  background: #f3f5f7;
                  color: #0f1720;
                }
                header {
                  position: sticky;
                  top: 0;
                  background: rgba(255, 255, 255, 0.9);
                  backdrop-filter: blur(8px);
                  border-bottom: 1px solid #d6dce3;
                  padding: 12px 20px;
                }
                main {
                  max-width: 1660px;
                  margin: 0 auto;
                  padding: 20px;
                }
                .row {
                  margin: 0 0 24px 0;
                }
                .row h2 {
                  margin: 0 0 12px 0;
                  font-size: 15px;
                  font-weight: 700;
                }
                .grid {
                  display: grid;
                  grid-template-columns: repeat(2, minmax(280px, 1fr));
                  gap: 16px;
                }
                .card {
                  margin: 0;
                  border: 1px solid #d6dce3;
                  background: #ffffff;
                  border-radius: 12px;
                  overflow: hidden;
                  box-shadow: 0 6px 20px rgba(16, 24, 40, 0.08);
                }
                .card h3 {
                  margin: 0;
                  padding: 10px 12px;
                  font-size: 14px;
                  font-weight: 600;
                  border-bottom: 1px solid #e5e7eb;
                  background: #f8fafc;
                }
                .card img {
                  width: 100%;
                  display: block;
                  background: white;
                }
                .missing {
                  padding: 24px 12px;
                  color: #6b7280;
                  font-size: 13px;
                }
                @media (max-width: 1100px) {
                  .grid {
                    grid-template-columns: 1fr;
                  }
                }
              </style>
            </head>
            <body>
              <header>
                <strong>Sagebrush iOS Screenshot Review (iPhone + iPad)</strong>
              </header>
              <main>
                \(rows)
              </main>
            </body>
            </html>
            """

        try html.write(
            to: outputDirectory.appendingPathComponent("review.html"),
            atomically: true,
            encoding: .utf8
        )
    }

    fileprivate static func requireFirstNotation() async throws -> NotationSummaryDTO {
        let notations = try await APIClient.shared.fetchNotationSummaries()
        guard let first = notations.first else {
            throw ScreenshotError.renderFailed("No notations available in demo backend")
        }
        return first
    }

    fileprivate static func answer(
        for component: QuestionStepDescriptor.Component
    ) -> NotationEngine.FlowInstance.AnswerValue {
        switch component {
        case .singleLineText:
            return .string("Sagebrush Demo LLC")
        case .multiLineText:
            return .string("Demo notes for review.")
        case .integer:
            return .string("1")
        case .decimal:
            return .string("1.0")
        case .toggle:
            return .choice("yes")
        case .radio(let choices):
            return .choice(choices.first?.value ?? "yes")
        case .picker(let choices):
            return .choice(choices.first?.value ?? "default")
        case .multiSelect(let choices):
            if let first = choices.first {
                return .multiChoice([first.value])
            }
            return .multiChoice([])
        case .date:
            return .choice("2026-02-26")
        case .dateTime:
            return .choice("2026-02-26T12:00:00Z")
        case .registeredAgent:
            return .metadata([
                "agent_type": "neon_law",
                "agent_name": "Neon Law",
                "agent_email": "support@sagebrush.services",
            ])
        case .organizationLookup:
            return .metadata(["entity_name": "Sagebrush Demo LLC"])
        case .secret, .phone, .email, .ssn, .ein, .fileUpload, .personLookup, .addressEntry, .signatureRequest,
            .notarizationRequest, .documentUpload, .issuanceLookup, .mailboxSelect:
            return .metadata(["value": "demo"])
        }
    }
}

private enum ScreenshotError: LocalizedError {
    case renderFailed(String)

    var errorDescription: String? {
        switch self {
        case .renderFailed(let message):
            return message
        }
    }
}
#endif
