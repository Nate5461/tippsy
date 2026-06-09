//
//  EmailVerificationView.swift
//  Tippsy
//
//  Email OTP verification step shown after registration. Confirms the 6-digit
//  code emailed to the user; on success the account is logged in.
//

import SwiftUI

struct EmailVerificationView: View {
    @Binding var isLoggedIn: Bool
    let userId: String
    let email: String

    @State private var code = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "envelope.badge.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Verify your email")
                .font(.title2)
                .fontWeight(.bold)

            Text("We sent a 6-digit code to \(email). Enter it below to finish setting up your account.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TextField("123456", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.title2)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
                .onChange(of: code) { _, newValue in
                    // Restrict input to at most 6 digits.
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(6))
                    if filtered != newValue { code = filtered }
                }

            Button(action: verify) {
                Group {
                    if isVerifying {
                        ProgressView().tint(.white)
                    } else {
                        Text("Verify").font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(code.count == 6 ? Color.blue : Color.gray)
                .cornerRadius(10)
            }
            .disabled(code.count != 6 || isVerifying)
            .padding(.horizontal)

            Button(action: resend) {
                Text(isResending ? "Sending…" : "Didn't get it? Resend code")
                    .font(.subheadline)
            }
            .disabled(isResending)

            Spacer()
        }
        .padding()
        .navigationBarBackButtonHidden(isVerifying)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Verification"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func verify() {
        isVerifying = true
        AuthService.verifyEmail(userId: userId, code: code) { result in
            DispatchQueue.main.async {
                isVerifying = false
                switch result {
                case .success:
                    // Token saved by AuthService; switch the app root to MainTabView.
                    isLoggedIn = true
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }

    private func resend() {
        isResending = true
        AuthService.resendVerification(userId: userId) { result in
            DispatchQueue.main.async {
                isResending = false
                switch result {
                case .success:
                    alertMessage = "A new code has been sent to your email."
                case .failure(let error):
                    alertMessage = error.localizedDescription
                }
                showAlert = true
            }
        }
    }
}
