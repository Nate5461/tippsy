//
//  SearchService.swift
//  Tippsy
//
//  Created by Nathan Bissett on 2025-03-18.
//

import Foundation

struct SearchService {
    static let shared = SearchService()
    
    static let baseURL = APIConfig.baseURL
    
    
    static func fetchTopUsers(query: String, completion: @escaping ([User]) -> Void) {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/users") else {
            completion([])
            return
        }
       
        if !query.isEmpty {
            urlComponents.queryItems = [URLQueryItem(name: "username", value: query)]
        }
       
        guard let url = urlComponents.url else {
            completion([])
            return
        }

        // /search/users requires auth, so attach the token and let
        // performAuthenticatedRequest detect an expired/invalid session.
        AuthService.performAuthenticatedRequest(url: url) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Error fetching users: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async { completion([]) }
                return
            }
            do {
                let users = try JSONDecoder().decode([User].self, from: data)
                DispatchQueue.main.async { completion(users) }
            } catch {
                print("Error decoding users: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    /// Unified, ranked search. `type` is one of "all", "recipes", "menus",
    /// "users", "ingredients". An empty query lets the backend fall back to its
    /// popularity/recency browse ordering. `source`/`maxAbv` apply to recipes,
    /// `kind` to ingredients. Always returns a SearchResults (empty buckets on error).
    static func search(query: String, type: String, source: String? = nil,
                       maxAbv: Double? = nil, kind: String? = nil,
                       completion: @escaping (SearchResults) -> Void) {
        let empty = SearchResults(recipes: nil, menus: nil, users: nil, ingredients: nil)
        guard var components = URLComponents(string: "\(baseURL)/search") else {
            completion(empty)
            return
        }
        var items = [URLQueryItem(name: "type", value: type)]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { items.append(URLQueryItem(name: "query", value: trimmed)) }
        if let source { items.append(URLQueryItem(name: "source", value: source)) }
        if let maxAbv { items.append(URLQueryItem(name: "maxAbv", value: String(maxAbv))) }
        if let kind { items.append(URLQueryItem(name: "kind", value: kind)) }
        components.queryItems = items

        guard let url = components.url else {
            completion(empty)
            return
        }

        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            guard let data, error == nil,
                  let results = try? JSONDecoder().decode(SearchResults.self, from: data) else {
                if let error { print("❌ Error searching: \(error.localizedDescription)") }
                DispatchQueue.main.async { completion(empty) }
                return
            }
            DispatchQueue.main.async { completion(results) }
        }
    }
}
