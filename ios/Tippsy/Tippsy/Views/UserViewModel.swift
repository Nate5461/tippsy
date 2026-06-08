//
//  UserViewModel.swift
//  Tippsy
//
//  Created by Joelle Ishimwe on 2025-01-05.
//

import Foundation
import Combine

class UserViewModel: ObservableObject {
    @Published var user: User? {
        didSet {
            print("User updated: \(String(describing: user))")
        }
    }
    @Published var reviews: [Review] = []
    @Published var followingUsers: [User] = [] // Add this to store the list of followed users
    @Published var isFollowing: Bool = false // Add this to track follow state

    // Initialize with a specific user (for navigating to other users' profiles)
    init(user: User? = nil, isFollowing: Bool = false) {
        self.user = user
        self.isFollowing = isFollowing
    }

    // Fetch the logged-in user's profile
    func fetchUserProfile() {
        
        guard self.user == nil, let userId = AuthService.loggedInUserId else { return }
        AuthService.fetchUserProfile(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let profile):
                    self.user = profile.user
                    self.reviews = profile.reviews
                    print("Fetched reviews: \(self.reviews)")
                case .failure(let error):
                    print("Error fetching profile: \(error.localizedDescription)")
                }
            }
        }
    }
    
    

    // Fetch the list of users the logged-in user is following
    func fetchFollowingUsers() {
        guard let userId = AuthService.loggedInUserId else { return }
        
        let url = URL(string: "\(AuthService.baseURL)/users/\(userId)/following")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching following users: \(error.localizedDescription)")
                return
            }
            
            if let data = data {
                do {
                    // Decode into an array of Follower objects
                    let followers = try JSONDecoder().decode([Follower].self, from: data)
                    DispatchQueue.main.async {
                        // Convert Follower objects to User objects for compatibility
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
                        // Filter out the logged-in user from the list
                        self.followingUsers = self.followingUsers.filter { $0.id != userId }
                        print("Fetched following users: \(self.followingUsers)") // Debugging
                    }
                } catch {
                    print("Failed to decode following users: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    // Check if the logged-in user is following this user
    func checkIfFollowing() {
        guard let userId = user?.id else { return }
        AuthService.checkIfFollowing(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let following):
                    self.isFollowing = following
                case .failure(let error):
                    print("Failed to check follow status: \(error.localizedDescription)")
                }
            }
        }
    }

    // Follow a user
        func followUser(completion: @escaping (Bool) -> Void) {
            guard let userId = user?.id else { return }
            AuthService.followUser(userId: userId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self.isFollowing = true
                        completion(true)
                    case .failure(let error):
                        print("Failed to follow: \(error.localizedDescription)")
                        completion(false)
                    }
                }
            }
        }

    
    // Update the user's profile
    func updateUserProfile(updatedUser: User, completion: @escaping (Bool) -> Void) {
        AuthService.updateUserProfile(user: updatedUser) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.user = updatedUser
                    completion(true)
                case .failure(let error):
                    print("Error updating profile: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    // Unfollow a user
    func unfollowUser(completion: @escaping (Bool) -> Void) {
        guard let userId = user?.id else { return }
        AuthService.unfollowUser(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.isFollowing = false
                    completion(true)
                case .failure(let error):
                    print("Failed to unfollow: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
    
    
}
