//
//  RecipeService.swift
//  Tippsy
//
//  API client for the recipe domain: search, detail, creation, reviews,
//  favourites, and the "what can I make from my bar" menu.
//

import Foundation
import UIKit

struct RecipeService {
    static let baseURL = APIConfig.baseURL

    /// Searches recipes. Pass nil source for all, nil maxAbv for no limit.
    /// An empty query returns the popular list.
    static func searchRecipes(query: String, source: String?, maxAbv: Double?, completion: @escaping ([RecipeSummary]) -> Void) {
        guard var components = URLComponents(string: "\(baseURL)/recipes") else {
            completion([])
            return
        }
        var items: [URLQueryItem] = []
        if !query.isEmpty { items.append(URLQueryItem(name: "query", value: query)) }
        if let source { items.append(URLQueryItem(name: "source", value: source)) }
        if let maxAbv { items.append(URLQueryItem(name: "maxAbv", value: String(maxAbv))) }
        if !items.isEmpty { components.queryItems = items }

        guard let url = components.url else {
            completion([])
            return
        }

        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            let recipes = decodeList([RecipeSummary].self, data: data, error: error, context: "recipes")
            DispatchQueue.main.async { completion(recipes) }
        }
    }

    static func fetchRecipe(id: String, completion: @escaping (RecipeDetail?) -> Void) {
        guard let url = URL(string: "\(baseURL)/recipes/\(id)") else {
            completion(nil)
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            var detail: RecipeDetail?
            if error == nil, let data {
                do {
                    detail = try JSONDecoder().decode(RecipeDetail.self, from: data)
                } catch {
                    print("Error decoding recipe detail: \(error)")
                }
            }
            DispatchQueue.main.async { completion(detail) }
        }
    }

    /// Creates a community recipe. The payload mirrors the POST /recipes body;
    /// callers build it via makeRecipePayload to keep key names in one place.
    static func createRecipe(payload: [String: Any], completion: @escaping (Result<RecipeDetail, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/recipes") else { return }

        AuthService.performAuthenticatedRequest(url: url, method: "POST", body: payload) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                    return
                }
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                   let data, let detail = try? JSONDecoder().decode(RecipeDetail.self, from: data) {
                    completion(.success(detail))
                } else {
                    let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                    let message = json?["error"] as? String ?? "Could not create recipe. Please try again."
                    completion(.failure(NSError(domain: "RecipeService", code: 400, userInfo: [NSLocalizedDescriptionKey: message])))
                }
            }
        }
    }

    static func fetchReviews(recipeId: String, completion: @escaping ([RecipeReview]) -> Void) {
        guard let url = URL(string: "\(baseURL)/recipes/\(recipeId)/reviews") else {
            completion([])
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            let reviews = decodeList([RecipeReview].self, data: data, error: error, context: "reviews")
            DispatchQueue.main.async { completion(reviews) }
        }
    }

    /// Posts a review as multipart/form-data (the photo rides along as JPEG).
    static func postReview(recipeId: String, rating: Int, comment: String?, impairment: Int?, photo: UIImage?, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/reviews") else { return }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = TokenStore.read() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        var fields: [(String, String)] = [
            ("recipe_id", recipeId),
            ("rating", String(rating)),
        ]
        if let comment, !comment.isEmpty { fields.append(("comment", comment)) }
        if let impairment { fields.append(("impairment_level", String(impairment))) }

        for (key, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        if let photo, let imageData = photo.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error {
                    completion(.failure(error))
                    return
                }
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    completion(.success(()))
                } else {
                    let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                    let message = json?["error"] as? String ?? "Could not submit review. Please try again."
                    completion(.failure(NSError(domain: "RecipeService", code: 400, userInfo: [NSLocalizedDescriptionKey: message])))
                }
            }
        }.resume()
    }

    static func favourite(recipeId: String, completion: @escaping (Bool) -> Void) {
        setFavourite(recipeId: recipeId, method: "POST", completion: completion)
    }

    static func unfavourite(recipeId: String, completion: @escaping (Bool) -> Void) {
        setFavourite(recipeId: recipeId, method: "DELETE", completion: completion)
    }

    private static func setFavourite(recipeId: String, method: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(baseURL)/recipes/\(recipeId)/favourite") else {
            completion(false)
            return
        }
        AuthService.performAuthenticatedRequest(url: url, method: method) { _, response, error in
            let ok = error == nil && (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } == true
            DispatchQueue.main.async { completion(ok) }
        }
    }

    static func fetchFavourites(userId: String, completion: @escaping ([RecipeSummary]) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/favourites") else {
            completion([])
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            let recipes = decodeList([RecipeSummary].self, data: data, error: error, context: "favourites")
            DispatchQueue.main.async { completion(recipes) }
        }
    }

    /// Popular recipes the user can make from their bar.
    static func fetchMenu(userId: String, completion: @escaping ([RecipeSummary]) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)/menu") else {
            completion([])
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            let recipes = decodeList([RecipeSummary].self, data: data, error: error, context: "menu")
            DispatchQueue.main.async { completion(recipes) }
        }
    }

    private static func decodeList<T: Decodable>(_ type: T.Type, data: Data?, error: Error?, context: String) -> T where T: ExpressibleByArrayLiteral {
        guard error == nil, let data else {
            print("Error fetching \(context): \(error?.localizedDescription ?? "no data")")
            return []
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Error decoding \(context): \(error)")
            return []
        }
    }
}
