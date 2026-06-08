//
//  SearchService.swift
//  Tippsy
//
//  Created by Nathan Bissett on 2025-03-18.
//

import Foundation

struct SearchService {
    static let shared = SearchService()
    
    static let baseURL = "http://localhost:3000"
    
    
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
       
        URLSession.shared.dataTask(with: url) { data, response, error in
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
        }.resume()
    }

    
    static func fetchTopDrinks(query: String, completion: @escaping ([Drink]) -> Void) {
        guard var urlComponents = URLComponents(string: "\(baseURL)/search/drinks") else {
            completion([])
            return
        }
       
        if !query.isEmpty {
            urlComponents.queryItems = [URLQueryItem(name: "query", value: query)]
        }
       
        guard let url = urlComponents.url else {
            completion([])
            return
        }
       
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Error fetching drinks: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async { completion([]) }
                return
            }
           
            do {
                let drinks = try JSONDecoder().decode([Drink].self, from: data)
                DispatchQueue.main.async { completion(drinks) }
            } catch {
                print("Error decoding drinks: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }.resume()
    }

}
