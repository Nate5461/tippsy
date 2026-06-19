//
//  MenuDetailView.swift
//  Tippsy
//
//  Read-only detail for a user-created menu: header (name, author, description,
//  tags) plus the menu's ordered cocktails. Reached by tapping a menu in search.
//

import SwiftUI

struct MenuDetailView: View {
    let menuId: String
    var measurePref: String = "metric"

    @State private var detail: MenuDetail?
    @State private var loaded = false

    private var drinkCount: String {
        let count = detail?.recipeCount ?? 0
        return "\(count) \(count == 1 ? "drink" : "drinks")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let detail {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(detail.name)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("by @\(detail.authorName) · \(drinkCount)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                        if let description = detail.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.85))
                        }
                        TagChips(tags: detail.tags)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if detail.recipes.isEmpty {
                        Text("This menu has no drinks yet.")
                            .font(.subheadline)
                            .italic()
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 20)
                    }
                    LazyVStack(spacing: 10) {
                        ForEach(detail.recipes) { recipe in
                            NavigationLink(destination: RecipeDetailView(recipeId: recipe.id, measurePref: measurePref)) {
                                RecipeCardView(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else if loaded {
                    Text("Menu not found.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 40)
                } else {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .barBackground()
        .navigationTitle("Menu")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            guard detail == nil else { return }
            MenuService.fetchMenu(id: menuId) { result in
                detail = result
                loaded = true
            }
        }
    }
}
