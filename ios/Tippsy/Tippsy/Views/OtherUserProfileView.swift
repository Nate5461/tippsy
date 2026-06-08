//
//  OtherUserProfileView.swift
//  Tippsy
//
//  Created by Kyloc Kwan on 2025-03-18.
//

import SwiftUI

struct OtherUserProfileView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var reviews: [Review] = []

    var body: some View {
        ScrollView {
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

                    // Follow/Unfollow Button
                    Button(action: {
                        if viewModel.isFollowing {
                            viewModel.unfollowUser { success in
                                if success {
                                    viewModel.isFollowing = false
                                }
                            }
                        } else {
                            viewModel.followUser { success in
                                if success {
                                    viewModel.isFollowing = true
                                }
                            }
                        }
                    }) {
                        Text(viewModel.isFollowing ? "Unfollow" : "Follow")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(viewModel.isFollowing ? Color.red : Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                } else {
                    ProgressView("Loading...")
                        .padding()
                }
            }
        }
        .onAppear {
            if let userId = viewModel.user?.id {
                AuthService.fetchUserProfile(userId: userId) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let profile):
                            viewModel.user = profile.user
                            reviews = profile.reviews
                        case .failure(let error):
                            print("Error fetching profile: \(error.localizedDescription)")
                        }
                    }
                }
            }
            viewModel.checkIfFollowing()
        }
    }
}
