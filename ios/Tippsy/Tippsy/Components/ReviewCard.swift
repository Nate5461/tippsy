//
//  ReviewCard.swift
//  Tippsy
//

import SwiftUI

struct ReviewCard: View {
    let review: Review

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let photoUrl = review.photoUrl, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .cornerRadius(10)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .cornerRadius(10)
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            Text("Drink: \(review.drinkName ?? "N/A")")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("Restaurant: \(review.restaurantName ?? "N/A")")
                .font(.subheadline)
                .foregroundColor(.white)
            Text("Rating: \(review.rating)/5")
                .font(.subheadline)
                .foregroundColor(.white)
            Text(review.comment)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(10)
        .shadow(radius: 5)
        .padding(.horizontal)
    }
}
