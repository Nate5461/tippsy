//
//  DiscoverView.swift
//  Tippsy
//
//  Search screen: recipes (with source + ABV filters) and users.
//

import SwiftUI

struct DiscoverView: View {
    enum SearchCategory {
        case recipes, users
    }

    @ObservedObject var viewModel: UserViewModel

    @State private var searchCategory: SearchCategory = .recipes
    @State private var recipes: [RecipeSummary] = []
    @State private var topUsers: [User] = []
    @State private var searchText = ""

    // Filters (recipes segment)
    @State private var sourceFilter: String? // nil = all, "official", "community"
    @State private var showFilters = false
    @State private var abvLimitEnabled = false
    @State private var abvLimit: Double = 20

    @State private var searchDebounce: DispatchWorkItem?

    private var measurePref: String {
        viewModel.user?.measurePref ?? "metric"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    categorySelector
                    searchBar

                    if searchCategory == .recipes {
                        filterRow
                        recipeList
                    } else {
                        userList
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
            .onAppear(perform: fetchData)
        }
    }

    // MARK: - Controls

    private var categorySelector: some View {
        HStack(spacing: 4) {
            segmentButton("Recipes", category: .recipes)
            segmentButton("Users", category: .users)
        }
        .padding(4)
        .background(.white.opacity(0.15))
        .clipShape(Capsule())
    }

    private func segmentButton(_ label: String, category: SearchCategory) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                searchCategory = category
            }
            fetchData()
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if searchCategory == category {
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    } else {
                        Color.clear
                    }
                }
                .clipShape(Capsule())
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            TextField(
                "Search...",
                text: $searchText,
                prompt: Text("Search...").foregroundColor(.white.opacity(0.6))
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
                    .onChange(of: abvLimitEnabled) { _, _ in fetchData() }

                    if abvLimitEnabled {
                        Slider(value: $abvLimit, in: 0...40, step: 1) { editing in
                            if !editing { fetchData() }
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
            fetchData()
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

    private var recipeList: some View {
        LazyVStack(spacing: 10) {
            if recipes.isEmpty {
                Text("No recipes found")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 30)
            }
            ForEach(recipes) { recipe in
                NavigationLink(destination: RecipeDetailView(recipeId: recipe.id, measurePref: measurePref)) {
                    RecipeCardView(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var userList: some View {
        LazyVStack(spacing: 10) {
            if topUsers.isEmpty {
                Text("No users found")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 30)
            }
            ForEach(topUsers) { user in
                NavigationLink(destination: OtherUserProfileView(viewModel: UserViewModel(user: user, isFollowing: isFollowingUser(user)))) {
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
                .buttonStyle(.plain)
            }
        }
    }

    private func isFollowingUser(_ user: User) -> Bool {
        guard let loggedInUserId = AuthService.loggedInUserId else { return false }
        return user.followers.contains { $0.id == loggedInUserId }
    }

    // MARK: - Data

    private func debounceFetch() {
        searchDebounce?.cancel()
        let task = DispatchWorkItem { fetchData() }
        searchDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func fetchData() {
        switch searchCategory {
        case .recipes:
            RecipeService.searchRecipes(
                query: searchText,
                source: sourceFilter,
                maxAbv: abvLimitEnabled ? abvLimit : nil
            ) { recipes = $0 }
        case .users:
            SearchService.fetchTopUsers(query: searchText) { users in
                topUsers = searchText.isEmpty ? Array(users.prefix(5)) : users
            }
        }
    }
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView(viewModel: UserViewModel())
    }
}
