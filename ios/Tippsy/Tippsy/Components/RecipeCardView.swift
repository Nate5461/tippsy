//
//  RecipeCardView.swift
//  Tippsy
//
//  Frosted summary card for a recipe, used in search results and the
//  "What can I make?" menu. Wrap in a NavigationLink at the call site.
//

import SwiftUI

struct RecipeCardView: View {
    let recipe: RecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                sourceBadge
            }

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 12) {
                strengthMeter

                if let estAbv = recipe.estAbv {
                    Text("\(Int(estAbv.rounded()))% ABV")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", recipe.averageRating))
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("(\(recipe.totalReviews))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .frostedCard()
    }

    private var subtitle: String {
        var parts = [recipe.method.capitalized]
        if let glass = recipe.glass, !glass.isEmpty {
            parts.append(glass.capitalized)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if recipe.source == "official" {
            Text("OFFICIAL")
                .font(.caption2.weight(.bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.orange)
                .clipShape(Capsule())
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text("COMMUNITY")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.2))
                    .clipShape(Capsule())

                if let authorName = recipe.authorName {
                    Text("by \(authorName)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    private var strengthMeter: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= recipe.strength ? Color.orange : Color.white.opacity(0.25))
                    .frame(width: 7, height: 7)
            }
        }
    }
}
