import SwiftUI

@available(iOS 18.0, *)
struct HomeView: View {
    @ObservedObject var viewModel: UserViewModel
    @Binding var isLoggedIn: Bool
    @State private var showEditProfile = false
    @State private var followingUsersReviews: [Review] = [] // Stores reviews from followed users
    @State private var followingUsers: [User] = [] // Stores the list of users you follow

    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.red.opacity(0.5)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        if let user = viewModel.user {
                            // User's profile section
                            userProfileSection(user: user)

                            // User's reviews section
                            userReviewsSection(reviews: viewModel.reviews)

                            // Profiles of followed users section
                            followingUsersSection(followingUsers: followingUsers)

                            // Reviews from followed users section
                            followingUsersReviewsSection(reviews: followingUsersReviews)
                        } else {
                            ProgressView("Loading...")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.fetchUserProfile()
                fetchFollowingUsersReviews() // Fetch reviews from followed users
                fetchFollowingUsers() // Fetch the list of users you follow
            }
        }
    }

    // MARK: - User Profile Section
    private func userProfileSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                AsyncImage(url: URL(string: user.profilePicture ?? "")) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                .shadow(radius: 10)

                VStack(alignment: .leading) {
                    Text(user.username)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Text("Followers: \(user.followers.count)")
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.horizontal)

            // Display the first 3 followers
            HStack {
                ForEach(user.followers.prefix(3), id: \.self) { follower in
                    NavigationLink(destination: OtherUserProfileView(viewModel: UserViewModel(user: User(id: follower.id, username: follower.username, email: "", profilePicture: follower.profilePicture, preferences: Preferences(drink: [], restaurant: []), followers: [], following: [])))) {
                        AsyncImage(url: URL(string: follower.profilePicture ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 10)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - User Reviews Section
    private func userReviewsSection(reviews: [Review]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Your Reviews")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)

            if reviews.isEmpty {
                Text("No reviews yet")
                    .italic()
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(reviews, id: \.id) { review in
                    ReviewCard(review: review)
                }
            }
        }
    }

    // MARK: - Following Users Section
    private func followingUsersSection(followingUsers: [User]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("People You Follow")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)

            if followingUsers.isEmpty {
                Text("You are not following anyone yet")
                    .italic()
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(followingUsers, id: \.id) { user in
                            NavigationLink(destination: OtherUserProfileView(viewModel: UserViewModel(user: user, isFollowing: isFollowingUser(user)))) {
                                VStack {
                                    AsyncImage(url: URL(string: user.profilePicture ?? "")) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Color.gray
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .shadow(radius: 10)
                                    
                                    Text(user.username)
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                .frame(width: 100)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Following Users Reviews Section
    private func followingUsersReviewsSection(reviews: [Review]) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Reviews from Followed Users")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal)

            if reviews.isEmpty {
                Text("No reviews from followed users yet")
                    .italic()
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            } else {
                ForEach(reviews, id: \.id) { review in
                    ReviewCard(review: review)
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func isFollowingUser(_ user: User) -> Bool {
        return followingUsers.contains { $0.id == user.id }
    }
    
    // Fetch reviews from followed users
    private func fetchFollowingUsersReviews() {
        guard let userId = AuthService.loggedInUserId else { return }

        let url = URL(string: "\(AuthService.baseURL)/users/\(userId)/following/reviews")!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching reviews from followed users: \(error.localizedDescription)")
                return
            }

            if let data = data {
                do {
                    let reviews = try JSONDecoder().decode([Review].self, from: data)
                    DispatchQueue.main.async {
                        followingUsersReviews = reviews
                    }
                } catch {
                    print("Failed to decode reviews: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    // Fetch the list of users you follow
    private func fetchFollowingUsers() {
        guard let userId = AuthService.loggedInUserId else { return }

        let url = URL(string: "\(AuthService.baseURL)/users/\(userId)/following")!

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching following users: \(error.localizedDescription)")
                return
            }

            if let data = data {
                do {
                    let followers = try JSONDecoder().decode([Follower].self, from: data)
                    DispatchQueue.main.async {
                        self.followingUsers = followers.map { follower in
                            User(
                                id: follower.id,
                                username: follower.username,
                                email: "", // Email is not provided in the response
                                profilePicture: follower.profilePicture,
                                preferences: Preferences(drink: [], restaurant: []),
                                followers: [],
                                following: []
                            )
                        }
                        self.followingUsers = self.followingUsers.filter { $0.id != userId }
                    }
                } catch {
                    print("Failed to decode following users: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
}

// MARK: - Reusable Review Card Component
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

@available(iOS 18.0, *)
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(viewModel: UserViewModel(), isLoggedIn: .constant(true))
    }
}
