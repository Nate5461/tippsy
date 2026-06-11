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

        performAuthenticatedRequest(url: url) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // A 404 here means the signed-in account no longer exists server-side
            // (e.g. it was deleted). Treat it like an expired session so the app
            // logs the user out instead of getting stuck on a broken profile.
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 404 {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .didReceiveUnauthorized, object: nil)
                }
                completion(.failure(NSError(domain: "AuthService", code: 404, userInfo: [NSLocalizedDescriptionKey: "This account no longer exists."])))
                return
            }

            if let data = data {
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
        }
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

    /// Saves the profile fields collected on the post-verification account setup
    /// screen: the user's chosen username (mandatory), optional display name and
    /// profile picture, and their preferred unit system.
    static func completeAccountSetup(userId: String, username: String, displayName: String?, profilePicture: String?, measurePref: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/users/\(userId)") else { return }

        var body: [String: Any] = [
            "username": username,
            "measurePref": measurePref
        ]
        if let displayName = displayName, !displayName.isEmpty {
            body["display_name"] = displayName
        }
        if let profilePicture = profilePicture {
            body["profile_picture"] = profilePicture
        }

        performAuthenticatedRequest(url: url, method: "PUT", body: body) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                AuthService.username = username
                completion(.success(()))
            } else {
                let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                completion(.failure(serverError(from: json, response: response)))
            }
        }
    }

    /// Registers a new account. The backend now requires email verification, so a
    /// successful response carries a `user_id` and no token. The caller should route
    /// the user to the email verification screen; a token is only issued once the
    /// emailed code is confirmed via `verifyEmail`.
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

            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            if let userId = json?["user_id"] as? String {
                AuthService.regUsername = username
                completion(.success(userId))
            } else {
                completion(.failure(serverError(from: json, response: response)))
            }
        }.resume()
    }

    /// Confirms the 6-digit code emailed during registration. On success the backend
    /// returns a JWT and the account is fully logged in (token saved, ids populated).
    static func verifyEmail(userId: String, code: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/verify-email") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["user_id": userId, "code": code])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            if let token = json?["token"] as? String,
               let user = json?["user"] as? [String: Any],
               let uid = user["id"] as? String,
               let uname = user["username"] as? String {
                loggedInUserId = uid
                AuthService.username = uname
                TokenStore.save(token)
                completion(.success(token))
            } else {
                completion(.failure(serverError(from: json, response: response)))
            }
        }.resume()
    }

    /// Requests a fresh verification code for the given user.
    static func resendVerification(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/auth/resend-verification") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["user_id": userId])

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                completion(.success(()))
            } else {
                let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
                completion(.failure(serverError(from: json, response: response)))
            }
        }.resume()
    }

    /// Builds a user-facing Error from a server `{ "error": "..." }` body, falling
    /// back to a generic message that includes the HTTP status when present.
    private static func serverError(from json: [String: Any]?, response: URLResponse?) -> Error {
        if let message = json?["error"] as? String {
            return NSError(domain: "AuthService", code: 400, userInfo: [NSLocalizedDescriptionKey: message])
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return NSError(domain: "AuthService", code: status, userInfo: [NSLocalizedDescriptionKey: "Something went wrong. Please try again."])
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
            
            let json = data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]
            if let token = json?["token"] as? String,
               let user = json?["user"] as? [String: Any],
               let userId = user["id"] as? String,
               let uname = user["username"] as? String {
                loggedInUserId = userId
                AuthService.username = uname
                TokenStore.save(token)
                completion(.success(token))
            } else {
                completion(.failure(serverError(from: json, response: response)))
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
