//
//  LoginView.swift
//  Tippsy
//

import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 20) {
                    // Logo
                    VStack(spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 250)
                    }
                    .padding(.bottom, 8)

                    // Input fields
                    VStack(spacing: 12) {
                        frostedTextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        frostedSecureField("Password", text: $password)

                        if isRegistering && !password.isEmpty {
                            passwordStrengthBar
                                .transition(.opacity)
                        }

                        if !isRegistering {
                            HStack {
                                Spacer()
                                Button("Forgot password?") {
                                    alertMessage = "Password reset coming soon."
                                    showAlert = true
                                }
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.75))
                            }
                            .transition(.opacity)
                        }

                        if isRegistering {
                            frostedSecureField("Confirm Password", text: $confirmPassword)
                                .transition(.move(edge: .top).combined(with: .opacity))

                            if !confirmPassword.isEmpty {
                                passwordMatchIndicator
                                    .transition(.opacity)
                            }
                        }
                    }

                    // Primary action button
                    Button(action: primaryAction) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isRegistering ? "Create Account" : "Login")
                        }
                    }
                    .buttonStyle(GradientCapsuleButtonStyle())
                    .disabled(isLoading)
                    .padding(.top, 4)

                    // Toggle between login and register
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isRegistering.toggle()
                            confirmPassword = ""
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isRegistering ? "Already have an account?" : "New here?")
                                .foregroundColor(.white.opacity(0.7))
                            Text(isRegistering ? "Login" : "Register here")
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 80)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .barBackground()
            .navigationDestination(for: String.self) { userId in
                EmailVerificationView(isLoggedIn: $isLoggedIn, userId: userId, email: email)
            }
            .alert("Notice", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func primaryAction() {
        isRegistering ? register() : login()
    }

    private func login() {
        isLoading = true
        AuthService.login(email: email, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    isLoggedIn = true
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    // MARK: - Strength helpers

    private var strengthScore: Int {
        let p = password
        guard !p.isEmpty else { return 0 }
        if p.count < 6 { return 1 }
        var score = 1
        if p.count >= 8 { score += 1 }
        if p.range(of: "[A-Z]", options: .regularExpression) != nil,
           p.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
        if p.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
        if p.range(of: "[^a-zA-Z0-9]", options: .regularExpression) != nil { score += 1 }
        return min(score, 4)
    }

    private var strengthFraction: Double { Double(strengthScore) / 4.0 }

    private var strengthColor: Color {
        switch strengthScore {
        case 1: return .red
        case 2: return .orange
        case 3: return Color(red: 0.85, green: 0.75, blue: 0.1)
        default: return .green
        }
    }

    private var strengthLabel: String {
        switch strengthScore {
        case 1: return "Weak"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Strong"
        default: return ""
        }
    }

    @ViewBuilder
    private var passwordStrengthBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(strengthColor)
                        .frame(width: geo.size.width * strengthFraction)
                }
            }
            .frame(height: 4)

            Text(strengthLabel)
                .font(.caption2)
                .foregroundColor(strengthColor)
        }
        .animation(.easeInOut(duration: 0.3), value: strengthScore)
    }

    @ViewBuilder
    private var passwordMatchIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: password == confirmPassword ? "checkmark.circle.fill" : "xmark.circle.fill")
            Text(password == confirmPassword ? "Passwords match" : "Passwords don't match")
        }
        .foregroundColor(password == confirmPassword ? .green : .red)
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: password == confirmPassword)
    }

    // MARK: - Actions

    private func register() {
        guard password == confirmPassword else {
            alertMessage = "Passwords don't match."
            showAlert = true
            return
        }
        let derivedUsername = email.components(separatedBy: "@").first ?? email
        isLoading = true
        AuthService.register(username: derivedUsername, email: email, password: password) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let userId):
                    path.append(userId)
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(isLoggedIn: .constant(false))
    }
}
