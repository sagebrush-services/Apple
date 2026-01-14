import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var onboardingManager: OnboardingManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingComingSoon = false
    @State private var showingWelcome = false
    @State private var pressedButton: AuthButton?

    enum AuthButton {
        case apple, google, passkey, email
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color("SagebrushGreen"),
                    Color("SagebrushGreen").opacity(0.8),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 80)

                    // Hero section
                    VStack(spacing: 16) {
                        Image("SagebrushLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

                        Text("Welcome to Sagebrush")
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .foregroundColor(.white)

                        Text("Sign in to continue")
                            .font(.system(size: 17, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.bottom, 60)

                    // Authentication options
                    VStack(spacing: 12) {
                        // Sign in with Apple
                        AuthenticationButton(
                            title: "Sign in with Apple",
                            icon: "apple.logo",
                            backgroundColor: .black,
                            foregroundColor: .white,
                            isPressed: pressedButton == .apple
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                pressedButton = .apple
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                pressedButton = nil
                                showingComingSoon = true
                            }
                        }

                        // Sign in with Google
                        AuthenticationButton(
                            title: "Sign in with Google",
                            icon: "g.circle.fill",
                            backgroundColor: .white,
                            foregroundColor: .black,
                            isPressed: pressedButton == .google
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                pressedButton = .google
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                pressedButton = nil
                                showingComingSoon = true
                            }
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Continue with Passkey
                        AuthenticationButton(
                            title: "Continue with Passkey",
                            icon: "key.fill",
                            backgroundColor: Color("SagebrushGreen").opacity(0.9),
                            foregroundColor: .white,
                            isPressed: pressedButton == .passkey,
                            isLoading: isLoading && pressedButton == .passkey
                        ) {
                            Task {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    pressedButton = .passkey
                                    isLoading = true
                                }
                                errorMessage = nil
                                do {
                                    try await authManager.signIn()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isLoading = false
                                pressedButton = nil
                            }
                        }

                        // Sign in with Email
                        AuthenticationButton(
                            title: "Sign in with Email",
                            icon: "envelope.fill",
                            backgroundColor: Color.white.opacity(0.9),
                            foregroundColor: Color("SagebrushGreen"),
                            isPressed: pressedButton == .email,
                            isLoading: isLoading && pressedButton == .email
                        ) {
                            Task {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    pressedButton = .email
                                    isLoading = true
                                }
                                errorMessage = nil
                                do {
                                    try await authManager.signIn()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isLoading = false
                                pressedButton = nil
                            }
                        }

                        // Error message
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                .padding(.top, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 24)

                    Spacer()
                        .frame(height: 40)

                    // Create account
                    HStack(spacing: 4) {
                        Text("Don't have an account?")
                            .font(.system(size: 15, weight: .regular, design: .default))
                            .foregroundColor(.white.opacity(0.8))

                        Button {
                            // For now, same flow as sign in
                            Task {
                                isLoading = true
                                errorMessage = nil
                                do {
                                    try await authManager.signIn()
                                } catch {
                                    errorMessage = error.localizedDescription
                                }
                                isLoading = false
                            }
                        } label: {
                            Text("Create Account")
                                .font(.system(size: 15, weight: .semibold, design: .default))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }

            // Info button overlay
            VStack {
                HStack {
                    Spacer()
                    Button {
                        showingWelcome = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 20)
                }
                Spacer()
            }
        }
        .alert("Coming Soon!", isPresented: $showingComingSoon) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This sign-in method will be available soon.")
        }
        .sheet(isPresented: $showingWelcome) {
            WelcomeView {
                showingWelcome = false
            }
            .environmentObject(onboardingManager)
        }
    }
}

// MARK: - Authentication Button

struct AuthenticationButton: View {
    let title: String
    let icon: String
    let backgroundColor: Color
    let foregroundColor: Color
    let isPressed: Bool
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .default))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .disabled(isLoading)
    }
}
