//
//  Models.swift
//  Tippsy
//
//  Created by Joelle Ishimwe on 2024-12-25.
//

import Foundation

struct User: Codable, Hashable, Identifiable {
    let id: String
    var username: String
    let email: String
    var profilePicture: String?
    var preferences: Preferences
    var followers: [Follower]
    var following: [Follower]

    // Conform to Equatable
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }

    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Follower: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let profilePicture: String?
    
    // Conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id) // Use `id` as the unique identifier for hashing
    }

    // Conform to Equatable
    static func == (lhs: Follower, rhs: Follower) -> Bool {
        lhs.id == rhs.id
    }
}

struct Review: Codable, Identifiable {
    let id: String?
    let drinkName: String?
    let restaurantName: String?
    let rating: Int
    let comment: String
    let impairmentLevel: Int
    let photoUrl: String?
    let userId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case drinkName
        case restaurantName
        case rating
        case comment
        case impairmentLevel = "impairment_level" // Map JSON field to Swift property
        case photoUrl
        case userId = "user_id"
    }
}

struct Preferences: Codable {
    var drink: [String]
    var restaurant: [String]
}

struct ProfileResponse: Codable {
    let user: User
    let reviews: [Review]
}

struct Location: Codable {
    let type: String
    let coordinates: [Double]
}

struct Restaurant: Codable, Identifiable {
    let id: String?
    let name: String
    let location: Location
    let averageRating: String
    let totalReviews: Int
    let drinks: [String] // Assuming drink names or IDs
    let reviews: [Review]
}

struct Drink: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let recipe: Recipe?
    let reviews: [Review]?
    let averageRating: Double?
    let totalReviews: Int?
}

struct Recipe: Codable {
    let ingredients: [String]?
    let instructions: String?
}

