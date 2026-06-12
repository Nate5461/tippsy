//
//  LogDrinkLandingView.swift
//  Tippsy
//
//  Root of the log/create tab, Letterboxd-style: search what you made and
//  log it (prefilled, editable — edits publish a modified variant), or
//  start a recipe from scratch.
//

import SwiftUI

struct LogDrinkLandingView: View {
    @ObservedObject var viewModel: UserViewModel

    @State private var searchText = ""
    @State private var results: [RecipeSummary] = []
    @State private var hasLoaded = false
    @State private var searchDebounce: DispatchWorkItem?
    @State private var loadingRecipeId: String?
    @State private var pendingLog: RecipeDetail?
    @State private var showScratch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchBar
                    scratchButton
                    resultsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .barBackground()
            .navigationTitle("Log a Drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(item: $pendingLog) { detail in
                RecipeEditorView(mode: .log(detail), viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showScratch) {
                RecipeEditorView(mode: .scratch, viewModel: viewModel)
            }
            .onAppear {
                if !hasLoaded { fetch() }
            }
        }
    }

    // MARK: - Pieces

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            TextField(
                "What did you make?",
                text: $searchText,
                prompt: Text("What did you make?").foregroundColor(.white.opacity(0.6))
            )
            .foregroundColor(.white)
            .tint(.white)
            .autocorrectionDisabled()
        }
        .padding()
        .background(.white.opacity(0.15))
        .cornerRadius(12)
        .onChange(of: searchText) { _, _ in
            debounceFetch()
        }
    }

    private var scratchButton: some View {
        Button {
            showScratch = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Start from scratch")
            }
        }
        .buttonStyle(GradientCapsuleButtonStyle())
    }

    @ViewBuilder
    private var resultsSection: some View {
        Text(searchText.isEmpty ? "Popular right now" : "Results")
            .font(.headline)
            .foregroundColor(.white)

        if results.isEmpty && hasLoaded {
            Text("Nothing found — start it from scratch instead")
                .font(.subheadline)
                .italic()
                .foregroundColor(.white.opacity(0.6))
        }

        ForEach(results) { recipe in
            Button {
                open(recipe)
            } label: {
                RecipeCardView(recipe: recipe)
                    .overlay(alignment: .bottomTrailing) {
                        if loadingRecipeId == recipe.id {
                            ProgressView()
                                .tint(.white)
                                .padding(10)
                        }
                    }
            }
            .buttonStyle(.plain)
            .disabled(loadingRecipeId != nil)
        }
    }

    // MARK: - Data

    private func debounceFetch() {
        searchDebounce?.cancel()
        let task = DispatchWorkItem { fetch() }
        searchDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func fetch() {
        RecipeService.searchRecipes(query: searchText, source: nil, maxAbv: nil) { recipes in
            results = recipes
            hasLoaded = true
        }
    }

    private func open(_ recipe: RecipeSummary) {
        loadingRecipeId = recipe.id
        RecipeService.fetchRecipe(id: recipe.id) { detail in
            loadingRecipeId = nil
            if let detail {
                pendingLog = detail
            }
        }
    }
}
