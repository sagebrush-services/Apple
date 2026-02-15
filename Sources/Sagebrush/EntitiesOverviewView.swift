import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EntitiesOverviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Entities")
                    .font(.largeTitle)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Entity management is on the way")
                        .font(.headline)
                    Text(
                        "We’re polishing a dedicated experience to review officers, addresses, and compliance tasks. In the meantime, visit the web dashboard or contact support@sagebrush.services for updates."
                    )
                    .font(.body)
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Coming soon")
                        .font(.title2)
                        .bold()
                    Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow {
                            ComingSoonCard(title: "Officer directory", icon: "person.2")
                            ComingSoonCard(title: "Address book", icon: "mappin.circle")
                        }
                        GridRow {
                            ComingSoonCard(title: "Compliance calendar", icon: "calendar.badge.clock")
                            ComingSoonCard(title: "Equity ledger", icon: "chart.pie")
                        }
                    }
                }
            }
            .padding()
        }
        .background(backgroundColor)
        .navigationTitle("Entities")
    }

    private var backgroundColor: Color {
        #if os(iOS)
        return Color(uiColor: .systemGroupedBackground)
        #else
        return Color(nsColor: .windowBackgroundColor)
        #endif
    }

    private struct ComingSoonCard: View {
        let title: String
        let icon: String

        var body: some View {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("On roadmap")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}
