//
//  DiscoverView.swift
//  Tippsy
//
//  Search screen. Empty state shows a hardcoded "Browse" list; once you start
//  searching (typing or tapping a browse row) the type tabs appear and results
//  come from the unified /search endpoint (All by default, narrowable by type).
//

import SwiftUI

struct DiscoverView: View {
    // Result-type tabs, shown only while searching.
    enum SearchScope: String, CaseIterable, Identifiable {
        case all, cocktails, menus, users, ingredients
        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:         return "All"
            case .cocktails:   return "Cocktails"
            case .menus:       return "Menus"
            case .users:       return "Users"
            case .ingredients: return "Ingredients"
            }
        }

        // Maps to the backend ?type= value.
        var apiType: String {
            switch self {
            case .all:         return "all"
            case .cocktails:   return "recipes"
            case .menus:       return "menus"
            case .users:       return "users"
            case .ingredients: return "ingredients"
            }
        }
    }

    // A hardcoded browse shortcut. Tapping one runs a preset search. These are
    // intentionally hardcoded for now; they'll become data-driven later.
    struct BrowsePreset: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let scope: SearchScope
        let query: String
        var source: String? = nil
        var maxAbv: Double? = nil
        var sortByRating = false
    }

    @ObservedObject var viewModel: UserViewModel

    @State private var searchText = ""
    @State private var scope: SearchScope = .all
    @State private var activePreset: BrowsePreset?
    @State private var results = SearchResults(recipes: nil, menus: nil, users: nil, ingredients: nil)

    // Cocktail sub-filters (shown only on the Cocktails scope).
    @State private var sourceFilter: String?
    @State private var showFilters = false
    @State private var abvLimitEnabled = false
    @State private var abvLimit: Double = 20

    @State private var searchDebounce: DispatchWorkItem?

    private let presets: [BrowsePreset] = [
        BrowsePreset(title: "Popular",        icon: "flame.fill",   scope: .cocktails, query: ""),
        BrowsePreset(title: "Highest rated",  icon: "star.fill",    scope: .cocktails, query: "", sortByRating: true),
        BrowsePreset(title: "Whiskey drinks", icon: "drop.fill",    scope: .cocktails, query: "whiskey"),
        BrowsePreset(title: "Summer list",    icon: "sun.max.fill", scope: .all,       query: "summer"),
        BrowsePreset(title: "Low ABV",        icon: "leaf.fill",    scope: .cocktails, query: "", maxAbv: 15),
        BrowsePreset(title: "Classics",       icon: "crown.fill",   scope: .cocktails, query: "", source: "official"),
    ]

    private var measurePref: String {
        viewModel.user?.measurePref ?? "metric"
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty || activePreset != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    searchBar

                    if isSearching {
                        scopeTabs
                        if scope == .cocktails { filterRow }
                        resultsSection
                    } else {
                        browseSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .barBackground()
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            TextField(
                "Search cocktails, menus, people…",
                text: $searchText,
                prompt: Text("Search cocktails, menus, people…").foregroundColor(.white.opacity(0.6))
            )
            .foregroundColor(.white)
            .tint(.white)
            .autocorrectionDisabled()
            if isSearching {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .background(.white.opacity(0.15))
        .cornerRadius(12)
        .onChange(of: searchText) { _, newValue in
            // A user-typed query takes over from any active browse preset.
            if !newValue.isEmpty { activePreset = nil }
            debounceFetch()
        }
    }

    // MARK: - Scope tabs

    private var scopeTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases) { item in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { scope = item }
                        runSearch()
                    } label: {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                if scope == item {
                                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                } else {
                                    Color.white.opacity(0.15)
                                }
                            }
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Browse (empty state)

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Browse")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(presets) { preset in
                Button { applyPreset(preset) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: preset.icon)
                            .font(.title3)
                            .foregroundColor(.orange)
                            .frame(width: 28)
                        Text(preset.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .frostedCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Cocktail sub-filters (source + ABV; only on the Cocktails scope)

    private var filterRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                sourceChip("All", value: nil)
                sourceChip("Official", value: "official")
                sourceChip("Community", value: "community")

                Spacer()

                Button {
                    withAnimation { showFilters.toggle() }
                } label: {
                    Image(systemName: abvLimitEnabled ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                        .font(.title3)
                        .foregroundColor(abvLimitEnabled ? .orange : .white.opacity(0.7))
                }
            }

            if showFilters {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $abvLimitEnabled) {
                        Text(abvLimitEnabled ? "Max strength: \(Int(abvLimit))% ABV" : "Limit strength")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .tint(.orange)
                    .onChange(of: abvLimitEnabled) { _, _ in runSearch() }

                    if abvLimitEnabled {
                        Slider(value: $abvLimit, in: 0...40, step: 1) { editing in
                            if !editing { runSearch() }
                        }
                        .tint(.orange)
                    }
                }
                .frostedCard()
                .transition(.opacity)
            }
        }
    }

    private func sourceChip(_ label: String, value: String?) -> some View {
        Button {
            sourceFilter = value
            runSearch()
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    if sourceFilter == value {
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    } else {
                        Color.white.opacity(0.15)
                    }
                }
                .clipShape(Capsule())
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        switch scope {
        case .all:         allResults
        case .cocktails:   recipeResults(displayRecipes)
        case .menus:       menuResults(results.menus ?? [])
        case .users:       userResults(results.users ?? [])
        case .ingredients: ingredientResults(results.ingredients ?? [])
        }
    }

    // Recipes to display, applying the preset's client-side rating sort if set.
    private var displayRecipes: [RecipeSummary] {
        let recipes = results.recipes ?? []
        if activePreset?.sortByRating == true {
            return recipes.sorted { $0.averageRating > $1.averageRating }
        }
        return recipes
    }

    private var allResults: some View {
        let recipes = displayRecipes
        let menus = results.menus ?? []
        let users = results.users ?? []
        let ingredients = results.ingredients ?? []
        let nothing = recipes.isEmpty && menus.isEmpty && users.isEmpty && ingredients.isEmpty

        return VStack(alignment: .leading, spacing: 18) {
            if nothing { emptyText }
            if !recipes.isEmpty { sectionHeaderGroup("Cocktails", target: .cocktails) { recipeRows(recipes) } }
            if !menus.isEmpty { sectionHeaderGroup("Menus", target: .menus) { menuRows(menus) } }
            if !users.isEmpty { sectionHeaderGroup("Users", target: .users) { userRows(users) } }
            if !ingredients.isEmpty { sectionHeaderGroup("Ingredients", target: .ingredients) { ingredientRows(ingredients) } }
        }
    }

    // A titled group in the All view with a "See all" that narrows the scope.
    @ViewBuilder
    private func sectionHeaderGroup<Content: View>(_ title: String, target: SearchScope, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline).foregroundColor(.white)
                Spacer()
                Button("See all") {
                    withAnimation { scope = target }
                    runSearch()
                }
                .font(.subheadline)
                .foregroundColor(.orange)
            }
            content()
        }
    }

    private func recipeResults(_ recipes: [RecipeSummary]) -> some View {
        LazyVStack(spacing: 10) {
            if recipes.isEmpty { emptyText }
            recipeRows(recipes)
        }
    }

    @ViewBuilder
    private func recipeRows(_ recipes: [RecipeSummary]) -> some View {
        ForEach(recipes) { recipe in
            NavigationLink(destination: RecipeDetailView(recipeId: recipe.id, measurePref: measurePref)) {
                RecipeCardView(recipe: recipe)
            }
            .buttonStyle(.plain)
        }
    }

    private func menuResults(_ menus: [MenuSummary]) -> some View {
        LazyVStack(spacing: 10) {
            if menus.isEmpty { emptyText }
            menuRows(menus)
        }
    }

    @ViewBuilder
    private func menuRows(_ menus: [MenuSummary]) -> some View {
        ForEach(menus) { menu in
            NavigationLink(destination: MenuDetailView(menuId: menu.id, measurePref: measurePref)) {
                MenuRow(menu: menu)
            }
            .buttonStyle(.plain)
        }
    }

    private func userResults(_ users: [UserSummary]) -> some View {
        LazyVStack(spacing: 10) {
            if users.isEmpty { emptyText }
            userRows(users)
        }
    }

    @ViewBuilder
    private func userRows(_ users: [UserSummary]) -> some View {
        ForEach(users) { user in
            NavigationLink(destination: OtherUserProfileView(viewModel: UserViewModel(user: user.asUser, isFollowing: false))) {
                userRow(user)
            }
            .buttonStyle(.plain)
        }
    }

    private func userRow(_ user: UserSummary) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: user.profilePicture ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("@\(user.username)")
                    .font(.headline)
                    .foregroundColor(.white)
                if let displayName = user.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .frostedCard()
    }

    private func ingredientResults(_ ingredients: [Ingredient]) -> some View {
        LazyVStack(spacing: 10) {
            if ingredients.isEmpty { emptyText }
            ingredientRows(ingredients)
        }
    }

    @ViewBuilder
    private func ingredientRows(_ ingredients: [Ingredient]) -> some View {
        ForEach(ingredients) { ingredient in
            HStack(spacing: 12) {
                Image(systemName: IngredientKind.icon(for: ingredient.kind))
                    .font(.title3)
                    .foregroundColor(.orange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ingredient.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(IngredientKind.label(for: ingredient.kind))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
            }
            .frostedCard()
        }
    }

    private var emptyText: some View {
        Text("No results")
            .font(.subheadline)
            .italic()
            .foregroundColor(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.top, 30)
    }

    // MARK: - Data

    private func clearSearch() {
        searchDebounce?.cancel()
        searchText = ""
        activePreset = nil
        scope = .all
        sourceFilter = nil
        abvLimitEnabled = false
        showFilters = false
        results = SearchResults(recipes: nil, menus: nil, users: nil, ingredients: nil)
    }

    private func applyPreset(_ preset: BrowsePreset) {
        activePreset = preset
        scope = preset.scope
        sourceFilter = preset.source
        if let maxAbv = preset.maxAbv {
            abvLimitEnabled = true
            abvLimit = maxAbv
        } else {
            abvLimitEnabled = false
        }
        searchText = preset.query
        runSearch()
    }

    private func debounceFetch() {
        searchDebounce?.cancel()
        let task = DispatchWorkItem { runSearch() }
        searchDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func runSearch() {
        guard isSearching else { return }
        let source = scope == .cocktails ? sourceFilter : nil
        let maxAbv = (scope == .cocktails && abvLimitEnabled) ? abvLimit : nil
        SearchService.search(query: searchText, type: scope.apiType, source: source, maxAbv: maxAbv) { fetched in
            results = fetched
        }
    }
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView(viewModel: UserViewModel())
    }
}
