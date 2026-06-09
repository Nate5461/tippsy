//
//  RegistrationView.swift
//  Tippsy
//
//  Created by Joelle Ishimwe on 2024-12-22.
//

import SwiftUI

struct RegistrationView: View {
    @Binding var isLoggedIn: Bool
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isRegistering = false
    @State private var pendingUserId: String?
    @State private var navigateToVerification = false

    var body: some View {
        VStack(spacing: 20) {
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .padding()

            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .padding()

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: register) {
                Group {
                    if isRegistering {
                        ProgressView().tint(.white)
                    } else {
                        Text("Register").font(.headline)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(isRegistering)
            .padding()

            Spacer()
        }
        .padding()
        .navigationDestination(isPresented: $navigateToVerification) {
            if let userId = pendingUserId {
                EmailVerificationView(isLoggedIn: $isLoggedIn, userId: userId, email: email)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Registration"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func register() {
        isRegistering = true
        AuthService.register(username: username, email: email, password: password) { result in
            DispatchQueue.main.async {
                isRegistering = false
                switch result {
                case .success(let userId):
                    pendingUserId = userId
                    navigateToVerification = true
                case .failure(let error):
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
}
