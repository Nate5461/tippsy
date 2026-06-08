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
    @State private var reviews: [Review] = []

    @State private var showEditProfile = false

    var body: some View {
        ScrollView { // Wrap the entire content in a ScrollView
            VStack {
                if let user = viewModel.user {
                    // Profile Picture
                    AsyncImage(url: URL(string: user.profilePicture ?? "")) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 4))
                    .shadow(radius: 10)
                    .padding(.top, 20)

                    // Username
                    Text(user.username)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.top, 10)

                    // Followers Count
                    Text("Followers: \(user.followers.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 5)

                    // Followers' Profile Pictures
                    HStack {
                        ForEach(user.followers.prefix(3), id: \.self) { follower in
                            AsyncImage(url: URL(string: follower.profilePicture ?? "")) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 5)
                        }
                    }
                    .padding(.top, 10)

                    // Reviews Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reviews (\(reviews.count))")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.top, 20)

                        if reviews.isEmpty {
                            Text("No reviews yet")
                                .italic()
                                .foregroundColor(.gray)
                                .padding(.top, 5)
                        } else {
                            ForEach(reviews.prefix(3), id: \.id) { review in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Drink: \(review.drinkName ?? "N/A")")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text("Restaurant: \(review.restaurantName ?? "N/A")")
                                        .font(.subheadline)
                                    Text("Rating: \(review.rating)/5")
                                        .font(.subheadline)
                                    Text(review.comment)
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 2)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Preferences Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Preferences")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.top, 20)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Drink Preferences")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            ForEach(user.preferences.drink, id: \.self) { drink in
                                Text(drink)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)

                        VStack(alignment: .leading, spacing: 5) {
                            Text("Restaurant Preferences")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            ForEach(user.preferences.restaurant, id: \.self) { restaurant in
                                Text(restaurant)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                    .padding(.horizontal)

                    // Edit Profile Button
                    Button(action: {
                        showEditProfile = true
                    }) {
                        Text("Edit Profile")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)

                    // Logout Button
                    Button(action: {
                        AuthService.loggedInUserId = nil
                        isLoggedIn = false
                        viewModel.user = nil
                        viewModel.reviews = []
                        viewModel.followingUsers = []
                    }) {
                        Text("Logout")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                } else {
                    ProgressView("Loading...")
                        .padding()
                }
            }
        }
        .onAppear {
            viewModel.fetchUserProfile()
            reviews = viewModel.reviews
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: viewModel)
        }
    }
}
