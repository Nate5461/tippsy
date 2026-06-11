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
    var displayName: String? = nil
    var profilePicture: String?
    var measurePref: String? = nil
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
    let rating: Int
    let comment: String
    let impairmentLevel: Int
    let photoUrl: String?
    let userId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case drinkName
        case rating
        case comment
        case impairmentLevel = "impairment_level" // Map JSON field to Swift property
        case photoUrl
        case userId = "user_id"
    }
}

struct Preferences: Codable {
    var drink: [String]
}

struct ProfileResponse: Codable {
    let user: User
    let reviews: [Review]
}

