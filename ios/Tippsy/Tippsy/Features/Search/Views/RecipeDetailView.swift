//
//  RecipeDetailView.swift
//  Tippsy
//
//  Full recipe page: header with badges and strength, ingredient lines
//  shown in the user's preferred units, instructions, and reviews with a
//  write-review sheet. Heart in the toolbar toggles favourite.
//

import SwiftUI

struct RecipeDetailView: View {
    let recipeId: String
    let measurePref: String

    @State private var recipe: RecipeDetail?
    @State private var reviews: [RecipeReview] = []
    @State private var isFavourite = false
    @State private var showReviewSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let recipe {
                    headerCard(recipe)
                    ingredientsCard(recipe)

                    if let instructions = recipe.instructions, !instructions.isEmpty {
                        instructionsCard(instructions)
                    }

                    reviewsCard
                } else {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 120)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .barBackground()
        .navigationTitle(recipe?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleFavourite) {
                    Image(systemName: isFavourite ? "heart.fill" : "heart")
                        .foregroundColor(isFavourite ? .red : .white)
                }
            }
        }
        .sheet(isPresented: $showReviewSheet) {
            WriteReviewSheet(recipeId: recipeId) {
                loadReviews()
            }
        }
        .onAppear(perform: load)
    }

    // MARK: - Sections

    @ViewBuilder
    private func headerCard(_ recipe: RecipeDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.white.opacity(0.1)
                }
                .frame(height: 180)
                .frame(maxWidth: .infinity)
                .clipped()
                .cornerRadius(10)
            }

            HStack(alignment: .top) {
                Text(recipe.name)
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                Spacer()
                sourceBadge(recipe)
            }

            if let parentId = recipe.parentRecipeId, let parentName = recipe.parentRecipeName {
                NavigationLink {
                    RecipeDetailView(recipeId: parentId, measurePref: measurePref)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Based on \(parentName)")
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.orange)
                }
            }

            if let description = recipe.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }

            Text(subtitle(recipe))
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 12) {
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { i in
                        Circle()
                            .fill(i <= recipe.strength ? Color.orange : Color.white.opacity(0.25))
                            .frame(width: 7, height: 7)
                    }
                }
                if let estAbv = recipe.estAbv {
                    Text("\(Int(estAbv.rounded()))% ABV")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow)
                    Text(String(format: "%.1f", recipe.averageRating))
                        .font(.caption).foregroundColor(.white)
                    Text("(\(recipe.totalReviews))")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                }
            }

            if let sweetness = recipe.sweetness {
                sweetnessBar(sweetness)
            }
        }
        .frostedCard()
    }

    @ViewBuilder
    private func sweetnessBar(_ sweetness: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.2))
                    Capsule()
                        .fill(Color.orange)
                        .frame(width: geo.size.width * Double(sweetness) / 10.0)
                }
            }
            .frame(height: 4)

            HStack {
                Text("Dry").font(.caption2).foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("Sweet").font(.caption2).foregroundColor(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private func ingredientsCard(_ recipe: RecipeDetail) -> some View {
        let regular = recipe.ingredients.filter { !$0.garnish }
        let garnish = recipe.ingredients.filter { $0.garnish }

        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(regular) { line in
                ingredientLineRow(line)
            }

            if !garnish.isEmpty {
                Text("Garnish")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.top, 4)

                ForEach(garnish) { line in
                    ingredientLineRow(line)
                }
            }
        }
        .frostedCard()
    }

    @ViewBuilder
    private func ingredientLineRow(_ line: RecipeLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(measurePref == "imperial" ? line.display.imperial : line.display.metric)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
                .frame(width: 80, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(line.ingredientName)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    if line.optional {
                        Text("(optional)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                if let note = line.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    @ViewBuilder
    private func instructionsCard(_ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions")
                .font(.headline)
                .foregroundColor(.white)
            Text(instructions)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
        }
        .frostedCard()
    }

    private var reviewsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reviews")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    showReviewSheet = true
                } label: {
                    Label("Write a review", systemImage: "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                }
            }

            if reviews.isEmpty {
                Text("No reviews yet — be the first!")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.white.opacity(0.6))
            } else {
                ForEach(reviews) { review in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(review.username)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)
                            Spacer()
                            if let rating = review.rating {
                                HStack(spacing: 2) {
                                    ForEach(1...5, id: \.self) { i in
                                        Image(systemName: i <= rating ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundColor(.yellow)
                                    }
                                }
                            } else {
                                Text("logged this")
                                    .font(.caption)
                                    .italic()
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        if let comment = review.comment, !comment.isEmpty {
                            Text(comment)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 6)

                    if review.id != reviews.last?.id {
                        Divider().background(.white.opacity(0.2))
                    }
                }
            }
        }
        .frostedCard()
    }

    // MARK: - Helpers

    private func subtitle(_ recipe: RecipeDetail) -> String {
        var parts = [recipe.method.capitalized, recipe.glassName]
        if let attribution = recipe.attribution, !attribution.isEmpty { parts.append(attribution) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func sourceBadge(_ recipe: RecipeDetail) -> some View {
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
                if recipe.parentRecipeId != nil {
                    Text("MODIFIED")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                if let authorName = recipe.authorName {
                    Text("by \(authorName)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Data

    private func load() {
        RecipeService.fetchRecipe(id: recipeId) { recipe = $0 }
        loadReviews()
        if let userId = AuthService.loggedInUserId {
            RecipeService.fetchFavourites(userId: userId) { favourites in
                isFavourite = favourites.contains { $0.id == recipeId }
            }
        }
    }

    private func loadReviews() {
        RecipeService.fetchReviews(recipeId: recipeId) { reviews = $0 }
    }

    private func toggleFavourite() {
        let wasFavourite = isFavourite
        isFavourite.toggle()
        let call = wasFavourite ? RecipeService.unfavourite : RecipeService.favourite
        call(recipeId) { ok in
            if !ok { isFavourite = wasFavourite }
        }
    }
}

// MARK: - Write review sheet

private struct WriteReviewSheet: View {
    let recipeId: String
    let onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int?
    @State private var comment = ""
    @State private var impairment = 1
    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rating")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= (rating ?? 0) ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(.yellow)
                                    .onTapGesture { rating = rating == i ? nil : i }
                            }
                        }
                        Text(rating == nil ? "Tap to rate — or just log it" : "Tap the same star to clear")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    frostedTextField("Say something about it", text: $comment)

                    HStack {
                        Text("Impairment level: \(impairment)")
                            .foregroundColor(.white)
                        Spacer()
                        Stepper("", value: $impairment, in: 1...5)
                            .labelsHidden()
                    }
                    .frostedCard()

                    // Photo upload for reviews exists server-side but the
                    // picker UX is deferred; placeholder per current scope.
                    HStack {
                        Image(systemName: "camera")
                        Text("Add photo — coming soon")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
                    .frostedCard()

                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text(rating == nil ? "Log It" : "Submit Review")
                        }
                    }
                    .buttonStyle(GradientCapsuleButtonStyle())
                    .disabled(isSubmitting)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .barBackground()
            .navigationTitle("Write a Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Review", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func submit() {
        isSubmitting = true
        RecipeService.postReview(
            recipeId: recipeId,
            rating: rating,
            comment: comment.isEmpty ? nil : comment,
            impairment: impairment,
            photo: nil
        ) { result in
            isSubmitting = false
            switch result {
            case .success:
                onSubmitted()
                dismiss()
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
