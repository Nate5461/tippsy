import Foundation
import Combine

class RestaurantViewModel: ObservableObject {
    @Published var restaurant: Restaurant?
    @Published var profileResponse: ProfileResponse?
    @Published var userProfiles: [String: User] = [:]
    @Published var errorMessage: String? // For displaying errors to the user

    func fetchRestaurantDetails(restaurantName: String) {
        guard let encodedName = restaurantName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                self.errorMessage = "Invalid restaurant name"
                return
            }

            let urlString = "http://localhost:3000/restaurants/name/\(encodedName)"
            print("Fetching URL: \(urlString)") // Add this line

            guard let url = URL(string: urlString) else {
                self.errorMessage = "Invalid URL"
                return
            }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching restaurant data: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                return
            }

            // Print the raw JSON data for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON Response: \(jsonString)")
            }

            do {
                let restaurantResponse = try JSONDecoder().decode(Restaurant.self, from: data)
                DispatchQueue.main.async {
                    self.restaurant = restaurantResponse
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error decoding restaurant data: \(error.localizedDescription)"
                }
            }
        }.resume()
    }

    func fetchUserProfile(userId: String) {
        let urlString = "http://localhost:3000/user/\(userId)"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid URL"
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Error fetching user profile: \(error.localizedDescription)"
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.errorMessage = "No data received"
                }
                return
            }

            do {
                let profileData = try JSONDecoder().decode(ProfileResponse.self, from: data)
                DispatchQueue.main.async {
                    self.profileResponse = profileData
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Error decoding user profile: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}
