//
//  AuthService.swift
//  Tippsy
//
//  Created by Joelle Ishimwe on 2024-12-22.
//


import Foundation

extension Notification.Name {
    static let didReceiveUnauthorized = Notification.Name("didReceiveUnauthorized")
}


struct AuthService {
    static let baseURL = APIConfig.baseURL
    static var loggedInUserId: String? // Global variable to store user ID
    static var username: String?     // Global variable to store username
    static var regUsername: String?

    static func performAuthenticatedRequest(url: URL, method: String = "GET", body: [String: Any]? = nil, completion: @escaping (Data?, URLResponse?, Error?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = TokenStore.read() {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .didReceiveUnauthorized, object: nil)
                }
            }
            completion(data, response, error)
        }.resume()
    }


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

        let body: [String: Any] = [
            "username": user.username,
            "profile_picture": user.profilePicture,
            "preferences": [
                "drink": user.preferences.drink,
            ]
        ]

        performAuthenticatedRequest(url: url, method: "PUT", body: body) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }
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
                if let token = json["token"] as? String {
                    TokenStore.save(token)
                }
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
                TokenStore.save(token)
                completion(.success(token))
            } else {
                completion(.failure(NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
            }
        }.resume()
    }
    static func followUser(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            guard let url = URL(string: "\(baseURL)/users/\(userId)/follow") else { return }

            performAuthenticatedRequest(url: url, method: "POST", body: nil) { _, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(()))
            }
        }

        static func unfollowUser(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
            print("Unfollow request to \(userId)") // Debugging
            
            guard let url = URL(string: "\(baseURL)/users/\(userId)/unfollow") else { return }

            performAuthenticatedRequest(url: url, method: "POST", body: nil) { _, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(()))
            }
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
