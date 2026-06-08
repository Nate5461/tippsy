//
//  RestaurantView.swift
//  Tippsy
//
//  Created by Kyloc Kwan on 2025-03-12.
//

import SwiftUI

struct RestaurantView: View {
    @ObservedObject var viewModel: RestaurantViewModel
    let restaurantName: String
    
    var body: some View {
        ScrollView {
            VStack {
                if let restaurant = viewModel.restaurant {
                    // Restaurant Name
                    Text(restaurant.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.top, 20)

                    // Average Rating
                    Text("Average Rating: \(restaurant.averageRating)/5")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue.opacity(0.7))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.top, 10)

                    Divider()
                        .padding(.vertical, 10)

                    // Reviews Section
                    if restaurant.reviews.isEmpty {
                        Text("No reviews yet")
                            .italic()
                            .foregroundColor(.gray)
                            .padding(.top, 20)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Reviews")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(.horizontal)

                            ForEach(restaurant.reviews, id: \.id) { review in
                                VStack(alignment: .leading, spacing: 5) {
                                    if let userId = review.userId, let user = viewModel.userProfiles[userId] {
                                        Text("User: \(user.username)")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("User: Anonymous")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                    }

                                    Text("Rating: \(review.rating)/5")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)

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
                        .padding(.horizontal)
                    }
                } else if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    ProgressView("Loading...")
                        .padding()
                }
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            viewModel.fetchRestaurantDetails(restaurantName: restaurantName)
            if let reviews = viewModel.restaurant?.reviews {
                for review in reviews {
                    if let userId = review.userId {
                        viewModel.fetchUserProfile(userId: userId)
                    }
                }
            }
        }
    }
}
