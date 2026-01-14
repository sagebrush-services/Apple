import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var currentPage = 0
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color("SagebrushGreen").opacity(0.1),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Welcome screens carousel
                TabView(selection: $currentPage) {
                    WelcomeScreen(
                        iconName: "building.2.fill",
                        headline: "Your Nevada Business Address",
                        description: "Professional Nevada address for incorporation, digital mail notifications, and worldwide forwarding"
                    )
                    .tag(0)

                    WelcomeScreen(
                        iconName: "checkmark.shield.fill",
                        headline: "Stay Compliant Effortlessly",
                        description: "Nevada Secretary of State filings, license compliance, and tax form management—all in one place"
                    )
                    .tag(1)

                    WelcomeScreen(
                        iconName: "chart.line.uptrend.xyaxis",
                        headline: "Manage Your Equity",
                        description: "Professional cap table tracking, stock administration, and legal coordination for fundraising and growth"
                    )
                    .tag(2)

                    FinalWelcomeScreen(onGetStarted: {
                        onboardingManager.markWelcomeAsSeen()
                        onDismiss()
                    })
                    .tag(3)
                }
#if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
#endif
            }
        }
    }
}

// MARK: - Welcome Screen Component

struct WelcomeScreen: View {
    let iconName: String
    let headline: String
    let description: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 80, weight: .light))
                .foregroundColor(Color("SagebrushGreen"))
                .padding(.bottom, 16)

            // Headline
            Text(headline)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Description
            Text(description)
                .font(.system(size: 17, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Final Welcome Screen

struct FinalWelcomeScreen: View {
    let onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            Image("SagebrushLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

            // Headline
            Text("Welcome to Sagebrush")
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundColor(.primary)
                .padding(.top, 8)

            // Description
            Text("$49/month for everything you need to run your Nevada business")
                .font(.system(size: 17, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .lineSpacing(4)

            Spacer()
            Spacer()

            // Get Started button
            Button(action: onGetStarted) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color("SagebrushGreen"))
                    .foregroundColor(.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 80)
        }
    }
}
