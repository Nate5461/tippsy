//
//  IngredientService.swift
//  Tippsy
//
//  API client for ingredients, measurement units, and the user's bar.
//

import Foundation

struct IngredientService {
    static let baseURL = APIConfig.baseURL

    // Units are fixed reference data — fetch once and reuse.
    private static var cachedUnits: [MeasureUnit]?

    /// Searches the official catalogue plus the caller's custom ingredients.
    static func searchIngredients(query: String, kind: String?, completion: @escaping ([Ingredient]) -> Void) {
        var items: [URLQueryItem] = []
        if !query.isEmpty { items.append(URLQueryItem(name: "query", value: query)) }
        if let kind { items.append(URLQueryItem(name: "kind", value: kind)) }
        fetchIngredients(queryItems: items, completion: completion)
    }

    /// Top-level generics for the browse grid (Vodka, Bourbon, Rum…), most
    /// common first, optionally limited to one kind.
    static func fetchTopLevel(kind: String?, completion: @escaping ([Ingredient]) -> Void) {
        var items = [URLQueryItem(name: "topLevel", value: "true")]
        if let kind { items.append(URLQueryItem(name: "kind", value: kind)) }
        fetchIngredients(queryItems: items, completion: completion)
    }

    /// Brands/styles under a generic (the drill-in), alphabetical.
    static func fetchBrands(parentId: String, completion: @escaping ([Ingredient]) -> Void) {
        fetchIngredients(queryItems: [URLQueryItem(name: "parentId", value: parentId)], completion: completion)
    }

    /// Shared `GET /ingredients` caller: builds the URL, authenticates, decodes.
    private static func fetchIngredients(queryItems: [URLQueryItem], completion: @escaping ([Ingredient]) -> Void) {
        guard var components = URLComponents(string: "\(baseURL)/ingredients") else {
            completion([])
            return
        }
        if !queryItems.isEmpty { components.queryItems = queryItems }
        guard let url = components.url else {
            completion([])
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            var ingredients: [Ingredient] = []
            if error == nil, let data {
                do {
                    ingredients = try JSONDecoder().decode([Ingredient].self, from: data)
                } catch {
                    print("Error decoding ingredients: \(error)")
                }
            }
            DispatchQueue.main.async { completion(ingredients) }
        }
    }

    static func createIngredient(name: String, kind: String, abv: Double?, completion: @escaping (Result<Ingredient, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/ingredients") else { return }

        var body: [String: Any] = ["name": name, "kind": kind]
        if let abv { body["abv"] = abv }

        AuthService.performAuthenticatedRequest(url: url, method: "POST", body: body) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                    return
                }
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let data, let ingredient = try? JSONDecoder().decode(Ingredient.self, from: data) {
                    completion(.success(ingredient))
                } else {
                    let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                    let message = json?["error"] as? String ?? "Could not create ingredient. Please try again."
                    completion(.failure(NSError(domain: "IngredientService", code: 400, userInfo: [NSLocalizedDescriptionKey: message])))
                }
            }
        }
    }

    static func fetchUnits(completion: @escaping ([MeasureUnit]) -> Void) {
        if let cachedUnits {
            completion(cachedUnits)
            return
        }
        guard let url = URL(string: "\(baseURL)/units") else {
            completion([])
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            var units: [MeasureUnit] = []
            if error == nil, let data {
                do {
                    units = try JSONDecoder().decode([MeasureUnit].self, from: data)
                } catch {
                    print("Error decoding units: \(error)")
                }
            }
            DispatchQueue.main.async {
                if !units.isEmpty { cachedUnits = units }
                completion(units)
            }
        }
    }

    // MARK: - Bar

    static func fetchBar(userId: String, completion: @escaping ([BarItem]) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/bar") else {
            completion([])
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            var items: [BarItem] = []
            if error == nil, let data {
                do {
                    items = try JSONDecoder().decode([BarItem].self, from: data)
                } catch {
                    print("Error decoding bar: \(error)")
                }
            }
            DispatchQueue.main.async { completion(items) }
        }
    }

    static func addToBar(userId: String, ingredientId: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/bar") else {
            completion(false)
            return
        }
        AuthService.performAuthenticatedRequest(url: url, method: "POST", body: ["ingredientId": ingredientId]) { _, response, error in
            let ok = error == nil && (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } == true
            DispatchQueue.main.async { completion(ok) }
        }
    }

    static func removeFromBar(userId: String, ingredientId: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/bar/\(ingredientId)") else {
            completion(false)
            return
        }
        AuthService.performAuthenticatedRequest(url: url, method: "DELETE") { _, response, error in
            let ok = error == nil && (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } == true
            DispatchQueue.main.async { completion(ok) }
        }
    }
}
