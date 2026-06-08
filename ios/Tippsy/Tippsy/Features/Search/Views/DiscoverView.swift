import SwiftUI

struct DiscoverView: View {
    enum SearchCategory {
        case users, drinks
    }

    @State private var searchCategory: SearchCategory = .users
    @State private var topUsers: [User] = []
    @State private var topDrinks: [Drink] = []
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    categorySelector
                    searchBar
                    if searchCategory == .users {
                        userList
                    } else if searchCategory == .drinks {
                        drinkList
                    }
                }
            }
            .navigationTitle("Discover")
            .padding(.top, 10)
            .onAppear {
                fetchData()
            }
        }
    }

    var categorySelector: some View {
        HStack {
            ForEach([("Users", SearchCategory.users), ("Drinks", SearchCategory.drinks)], id: \.1) { label, category in
                Button(action: {
                    searchCategory = category
                    fetchData()
                }) {
                    Text(label)
                        .padding()
                        .foregroundColor(.white)
                        .background(
                            searchCategory == category ?
                            AnyView(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)) :
                            AnyView(Color.gray.opacity(0.2))
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
    }

    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
        .onChange(of: searchText) { _ in
            fetchData()
        }
    }

    var userList: some View {
        VStack(alignment: .leading) {
            Text("Users")
                .font(.headline)
                .padding(.leading)

            LazyVStack {
                ForEach(topUsers) { user in
                    NavigationLink(destination: OtherUserProfileView(viewModel: UserViewModel(user: user, isFollowing: isFollowingUser(user)))) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func isFollowingUser(_ user: User) -> Bool {
        guard let loggedInUserId = AuthService.loggedInUserId else { return false }
        return user.followers.contains { $0.id == loggedInUserId }
    }

    var drinkList: some View {
        VStack(alignment: .leading) {
            Text("Drinks")
                .font(.headline)
                .padding(.leading)

            LazyVStack {
                ForEach(topDrinks) { drink in
                    VStack(alignment: .leading) {
                        Text(drink.name)
                            .font(.headline)
                        Text(drink.category)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        HStack {
                            Text("Average Rating: \(String(format: "%.1f", drink.averageRating ?? 0.0))")
                                .font(.subheadline)
                                .foregroundColor(.blue)

                            Text("Reviews: \(drink.totalReviews ?? 0)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
            }
            .padding(.horizontal)
        }
    }

    func fetchData() {
        switch searchCategory {
        case .users:
            SearchService.fetchTopUsers(query: searchText) { users in
                DispatchQueue.main.async {
                    self.topUsers = searchText.isEmpty ? Array(users.prefix(5)) : users
                }
            }
        case .drinks:
            SearchService.fetchTopDrinks(query: searchText) { drinks in
                DispatchQueue.main.async {
                    self.topDrinks = searchText.isEmpty ? Array(drinks.prefix(5)) : drinks
                }
            }
        }
    }
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView()
    }
}
