//
//  AuthService.swift
//  Tippsy
//
//  Created by Joelle Ishimwe on 2024-12-22.
//

import Foundation

struct AuthService {
    static let baseURL = "http://localhost:3000" // User authentication backend URL
    static var loggedInUserId: String? // Global variable to store user ID
    static var username: String?     // Global variable to store username
    static var regUsername: String?

    static func fetchUserProfile(userId: String, completion: @escaping (Result<(user: User, reviews: [Review]), Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)") else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let data = data {
                print("Profile response: \(String(data: data, encoding: .utf8) ?? "No data")") // Debugging
                do {
                    let response = try JSONDecoder().decode(ProfileResponse.self, from: data)
                    completion(.success((response.user, response.reviews)))
                } catch {
                    print("Decoding error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            } else {
                completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
            }
        }.resume()
    }


    static func updateUserProfile(user: User, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(user.id)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "username": user.username,
            "profile_picture": user.profilePicture,
            "preferences": [
                "drink": user.preferences.drink,
                "restaurant": user.preferences.restaurant,
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }

    static func register(username: String, email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/register") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "username": username,
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let user = json["user"] as? [String: Any],
               let userId = user["id"] as? String,
               let uname = user["username"] as? String {
                loggedInUserId = userId
                AuthService.username = uname
                completion(.success("Registration successful!"))
            } else {
                completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                    }
        }.resume()
    }
    
    
    static func login(email: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/login") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "email": email,
            "password": password
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String,
               let user = json["user"] as? [String: Any],
               let userId = user["id"] as? String,
               let uname = user["username"] as? String {
                loggedInUserId = userId
                AuthService.username = uname
                completion(.success(token))
            } else {
                completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
            }
        }.resume()
    }
    static func followUser(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let loggedInUserId = loggedInUserId else {
                completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
                return
            }

            guard let url = URL(string: "\(baseURL)/users/\(loggedInUserId)/follow") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "followUserId": userId
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(()))
            }.resume()
        }

        static func unfollowUser(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let loggedInUserId = loggedInUserId else {
                completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
                return
            }
            
            print("Unfollow request from \(loggedInUserId) to \(userId)") // Debugging
            
            guard let url = URL(string: "\(baseURL)/users/\(loggedInUserId)/unfollow") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "unfollowUserId": userId
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: body)

            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(()))
            }.resume()
        }

        static func checkIfFollowing(userId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
            guard let loggedInUserId = loggedInUserId else {
                completion(.failure(NSError(domain: "", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
                return
            }

            guard let url = URL(string: "\(baseURL)/users/\(userId)/followers") else { return }

            URLSession.shared.dataTask(with: url) { data, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let data = data {
                    do {
                        let followers = try JSONDecoder().decode([User].self, from: data)
                        let isFollowing = followers.contains { $0.id == loggedInUserId }
                        completion(.success(isFollowing))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
            }.resume()
        }
}
