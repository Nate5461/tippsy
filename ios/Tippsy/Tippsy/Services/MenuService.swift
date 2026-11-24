//
//  MenuService.swift
//  Tippsy
//
//  User-created menus (lists of cocktails). For now the iOS app only reads menus
//  (search + detail); creating/editing menus is future work.
//

import Foundation

struct MenuService {
    static let baseURL = APIConfig.baseURL

    /// GET /menus/{id} — a menu's detail (summary fields + its ordered recipes).
    static func fetchMenu(id: String, completion: @escaping (MenuDetail?) -> Void) {
        guard let url = URL(string: "\(baseURL)/menus/\(id)") else {
            completion(nil)
            return
        }
        AuthService.performAuthenticatedRequest(url: url) { data, _, error in
            guard let data, error == nil,
                  let detail = try? JSONDecoder().decode(MenuDetail.self, from: data) else {
                if let error { print("❌ Error fetching menu: \(error.localizedDescription)") }
                DispatchQueue.main.async { completion(nil) }
                return
            }
            DispatchQueue.main.async { completion(detail) }
        }
    }
}
