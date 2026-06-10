//
//  AccountSetupView.swift
//  Tippsy
//
//  Final step of registration, shown after email verification. Lets the user
//  pick their real username (mandatory) and fill in optional profile details
//  before entering the app.
//

import SwiftUI
import PhotosUI

struct AccountSetupView: View {
    @Binding var isLoggedIn: Bool
    let userId: String

    @State private var username = AuthService.username ?? ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var measurePref: MeasurementUnit = .metric
    @State private var profileImage: UIImage?
    @State private var showPhotoPicker = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Set Up Your Account")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("Tell us a bit about yourself. You can always change this later.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 8)

                profilePicturePicker

                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        frostedTextField("Username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Text("Required")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    HStack(spacing: 12) {
                        frostedTextField("First Name (optional)", text: $firstName)
                            .textContentType(.givenName)
                        frostedTextField("Last Name (optional)", text: $lastName)
                            .textContentType(.familyName)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preferred Units")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))

                    measurementPicker
                }

                Button(action: finishSetup) {
                    Group {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Finish")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                }
                .disabled(isLoading || username.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 32)
            .padding(.top, 80)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background {
            Image("bar_background")
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showPhotoPicker) {
            PHPickerViewControllerWrapper(selectedImage: $profileImage)
        }
        .alert("Notice", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    @ViewBuilder
    private var profilePicturePicker: some View {
        Button {
            showPhotoPicker = true
        } label: {
            ZStack(alignment: .bottomTrailing) {
                if let profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 96, height: 96)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.7))
                        )
                }

                Image(systemName: "camera.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.black.opacity(0.55), lineWidth: 2))
            }
        }
    }

    @ViewBuilder
    private var measurementPicker: some View {
        HStack(spacing: 4) {
            ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                Text(unit.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(unit == measurePref ? .black : .white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(unit == measurePref ? Color.white : Color.clear)
                    .clipShape(Capsule())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            measurePref = unit
                        }
                    }
            }
        }
        .padding(4)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private func frostedTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(
            placeholder,
            text: text,
            prompt: Text(placeholder).foregroundColor(.white.opacity(0.6))
        )
        .foregroundColor(.white)
        .tint(.white)
        .padding()
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.15))
        .cornerRadius(12)
    }

    private func finishSetup() {
        let trimmedUsername = username.trimmingCharacters(in: .whitespaces)
        guard !trimmedUsername.isEmpty else { return }

        let displayName = [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let profilePictureBase64 = profileImage.flatMap(convertImageToBase64)

        isLoading = true
        AuthService.completeAccountSetup(
            userId: userId,
            username: trimmedUsername,
            displayName: displayName.isEmpty ? nil : displayName,
            profilePicture: profilePictureBase64,
            measurePref: measurePref.rawValue
        ) { result in
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
}

enum MeasurementUnit: String, CaseIterable {
    case metric
    case imperial

    var label: String {
        switch self {
        case .metric: return "Metric (mL)"
        case .imperial: return "Imperial (oz)"
        }
    }
}

struct AccountSetupView_Previews: PreviewProvider {
    static var previews: some View {
        AccountSetupView(isLoggedIn: .constant(false), userId: "preview-user-id")
    }
}
