//
//  ProfileView.swift
//  Tippsy
//
//  Created by Nathan Bissett on 2024-12-04.
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var viewModel: UserViewModel
    @Binding var isLoggedIn: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let user = viewModel.user {
                    // Profile Picture
                    AsyncImage(url: URL(string: user.profilePicture ?? "")) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundColor(.gray)
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 10)
                    .padding(.top, 20)

                    // Username
                    Text("@\(user.username)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    // Name
                    if let displayName = user.displayName, !displayName.isEmpty {
                        Text(displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // Measurement Unit
                    Text(measurementLabel(for: user.measurePref))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                } else {
                    ProgressView("Loading...")
                        .padding()
                }

                // Logout Button - always available, even if the profile failed to load.
                Button(action: logout) {
                    Text("Logout")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.top, 30)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            viewModel.fetchUserProfile()
        }
    }

    private func measurementLabel(for measurePref: String?) -> String {
        switch measurePref {
        case "imperial": return "Imperial (oz)"
        default: return "Metric (mL)"
        }
    }

    private func logout() {
        TokenStore.delete()
        AuthService.loggedInUserId = nil
        AuthService.username = nil
        isLoggedIn = false
        viewModel.user = nil
        viewModel.reviews = []
        viewModel.followingUsers = []
    }
}
