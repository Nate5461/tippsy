//
//  GlassService.swift
//  Tippsy
//
//  API client for the server-managed glass catalogue. Glass is a required,
//  picker-only field on recipes, so the list is fetched once and reused.
//

import Foundation

struct GlassService {
    static let baseURL = APIConfig.baseURL

    // Glasses are fixed reference data — fetch once and reuse.
    private static var cachedGlasses: [GlassType]?

    static func fetchGlasses(completion: @escaping ([GlassType]) -> Void) {
        if let cachedGlasses {
            completion(cachedGlasses)
            return
        }
        guard let url = URL(string: "\(baseURL)/glasses") else {
            completion([])
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            var glasses: [GlassType] = []
            if error == nil, let data {
                do {
                    glasses = try JSONDecoder().decode([GlassType].self, from: data)
                } catch {
                    print("Error decoding glasses: \(error)")
                }
            }
            DispatchQueue.main.async {
                if !glasses.isEmpty { cachedGlasses = glasses }
                completion(glasses)
            }
        }
    }
}
