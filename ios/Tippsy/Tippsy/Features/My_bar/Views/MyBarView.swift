//
//  MyBarView.swift
//  Tippsy
//
//  The user's bar: ingredients they own grouped by kind, plus the
//  "What can I make?" menu of recipes makeable from those ingredients.
//

import SwiftUI

struct MyBarView: View {
    enum Segment {
        case bar, menu
    }

    @ObservedObject var viewModel: UserViewModel

    @State private var segment: Segment = .bar
    @State private var items: [BarItem] = []
    @State private var menu: [RecipeSummary] = []
    @State private var hasLoadedBar = false
    @State private var showIngredientPicker = false

    private var measurePref: String {
        viewModel.user?.measurePref ?? "metric"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    segmentSelector

                    if segment == .bar {
                        barList
                    } else {
                        menuList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .barBackground()
            .navigationTitle("My Bar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showIngredientPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showIngredientPicker) {
                AddToBarSheet { ingredient in
                    add(ingredient)
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: - Controls

    private var segmentSelector: some View {
        HStack(spacing: 4) {
            segmentButton("My Bar", value: .bar)
            segmentButton("What can I make?", value: .menu)
        }
        .padding(4)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }

    private func segmentButton(_ label: String, value: Segment) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                segment = value
            }
            if value == .menu { loadMenu() }
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if segment == value {
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    } else {
                        Color.clear
                    }
                }
                .clipShape(Capsule())
        }
    }

    // MARK: - Bar segment

    private var groupedItems: [(kind: String, items: [BarItem])] {
        Dictionary(grouping: items, by: \.kind)
            .map { (kind: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
            .sorted { IngredientKind.sortIndex(for: $0.kind) < IngredientKind.sortIndex(for: $1.kind) }
    }

    @ViewBuilder
    private var barList: some View {
        if items.isEmpty && hasLoadedBar {
            emptyState(
                icon: "wineglass",
                title: "Your bar is empty",
                message: "Add what you've got and we'll show you what you can make."
            )
        } else {
            ForEach(groupedItems, id: \.kind) { group in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: IngredientKind.icon(for: group.kind))
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text(IngredientKind.label(for: group.kind))
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(group.items.count)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(group.items) { item in
                                BottleCard(
                                    name: item.name,
                                    kind: item.kind,
                                    imageUrl: item.imageUrl,
                                    abv: item.abv,
                                    custom: item.custom,
                                    onRemove: { remove(item) }
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - Menu segment

    @ViewBuilder
    private var menuList: some View {
        if menu.isEmpty {
            emptyState(
                icon: "sparkles",
                title: "Nothing to mix yet",
                message: "Add more ingredients to your bar to unlock recipes."
            )
        } else {
            LazyVStack(spacing: 10) {
                ForEach(menu) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipeId: recipe.id, measurePref: measurePref)) {
                        RecipeCardView(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.5))
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.horizontal, 30)
    }

    // MARK: - Data

    private func load() {
        guard let userId = AuthService.loggedInUserId else { return }
        IngredientService.fetchBar(userId: userId) { fetched in
            items = fetched
            hasLoadedBar = true
        }
        if segment == .menu { loadMenu() }
    }

    private func loadMenu() {
        guard let userId = AuthService.loggedInUserId else { return }
        RecipeService.fetchMenu(userId: userId) { menu = $0 }
    }

    private func add(_ ingredient: Ingredient) {
        guard let userId = AuthService.loggedInUserId else { return }
        IngredientService.addToBar(userId: userId, ingredientId: ingredient.id) { ok in
            if ok { load() }
        }
    }

    private func remove(_ item: BarItem) {
        guard let userId = AuthService.loggedInUserId else { return }
        let removed = item
        items.removeAll { $0.id == item.id }
        IngredientService.removeFromBar(userId: userId, ingredientId: item.id) { ok in
            if !ok { items.append(removed) }
        }
    }
}
