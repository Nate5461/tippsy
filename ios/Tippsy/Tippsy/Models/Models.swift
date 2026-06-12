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

// Mirrors the shared reviewDTO (camelCase). A nil rating is a bare log
// ("I made this") rather than a scored review.
struct Review: Codable, Identifiable {
    let id: String?
    let recipeName: String?
    let rating: Int?
    let comment: String?
    let impairmentLevel: Int?
    let photoUrl: String?
    let userId: String?
}

struct Preferences: Codable {
    var drink: [String]
}

struct ProfileResponse: Codable {
    let user: User
    let reviews: [Review]
}

