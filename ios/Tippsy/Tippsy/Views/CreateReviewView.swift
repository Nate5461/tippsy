//
//  CreateReviewView.swift
//  Tippsy
//
//  Created by Joelle Ishimwe on 2024-12-24.
//  Expanded version with Drink Search Bar instead of a drop-down.
//

import SwiftUI
import PhotosUI

struct CreateReviewView: View {
    @State private var selectedRestaurant: String = ""
    @State private var selectedDrink: String = ""
    @State private var rating: Int = 1
    @State private var impairmentLevel: Int = 1
    @State private var comment: String = ""
    @State private var restaurantOptions: [(id: String, name: String)] = []
    @State private var drinkOptions: [(id: String, name: String)] = []
    @State private var selectedPhoto: UIImage? = nil
    @State private var showPhotoPicker = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // New state properties for drink search bar functionality
    @State private var drinkSearchText: String = ""
    @State private var showDrinkSuggestions: Bool = false
    @State private var restaurantSearchText: String = ""
    @State private var showRestaurantSuggestions: Bool = false
    
    // Computed property to filter drink suggestions based on the search text.
    private var drinkSearchSuggestions: [(id: String, name: String)] {
        if drinkSearchText.isEmpty { return [] }
        let filtered = drinkOptions.filter { $0.name.lowercased().contains(drinkSearchText.lowercased()) }
        return Array(filtered.prefix(3))
    }

    private var restaurantSearchSuggestions: [(id: String, name: String)] {
        if restaurantSearchText.isEmpty { return [] }
        let filtered = restaurantOptions.filter { $0.name.lowercased().contains(restaurantSearchText.lowercased()) }
        return Array(filtered.prefix(3))
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.3), Color.red.opacity(0.5)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Create a Review")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 20)
                    
                    // Photo Picker Section
                    photoPickerSection
                    
                    // Restaurant Picker Section (remains as a drop-down)
                    restaurantSearchSection
                        .onAppear {
                            fetchRestaurants()
                        }
                    
                    // Drink Search Section (replaces drop-down with a search bar)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Search for Drink")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if selectedDrink.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                TextField("Search for a drink...", text: $drinkSearchText, onEditingChanged: { isEditing in
                                    showDrinkSuggestions = isEditing
                                })
                                .onSubmit {
                                    if !drinkSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                                        // Check for an exact match first
                                        if let match = drinkOptions.first(where: { $0.name.lowercased() == drinkSearchText.lowercased() }) {
                                            selectedDrink = match.id
                                        } else {
                                            // Otherwise, use the typed text
                                            selectedDrink = drinkSearchText
                                        }
                                    }
                                }
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.horizontal)
                                
                                if showDrinkSuggestions, !drinkSearchSuggestions.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(drinkSearchSuggestions, id: \.id) { drink in
                                            Text(drink.name)
                                                .padding(8)
                                                .onTapGesture {
                                                    selectedDrink = drink.id
                                                    drinkSearchText = drink.name
                                                    showDrinkSuggestions = false
                                                }
                                        }
                                    }
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                }
                            }
                        } else {
                            HStack {
                                Text("Selected Drink: \(drinkSearchText)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Button("Change") {
                                    selectedDrink = ""
                                    drinkSearchText = ""
                                }
                                .foregroundColor(.blue)
                            }
                            .padding(.horizontal)
                        }
                    }
                    .onAppear {
                        fetchDrinks()
                    }
                    
                    // Rating Picker Section
                    stepperSection(title: "Rating", value: $rating, range: 1...5)
                    
                    // Impairment Level Picker Section
                    stepperSection(title: "Impairment Level", value: $impairmentLevel, range: 1...5)
                    
                    // Comment TextField Section
                    commentSection
                    
                    // Submit Button Section
                    submitButton
                }
                .padding()
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectedImage: $selectedPhoto)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Review Submission"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private var photoPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a Photo")
                .font(.headline)
                .foregroundColor(.white)
            if let photo = selectedPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .cornerRadius(10)
                    .shadow(radius: 5)
            } else {
                Button(action: {
                    showPhotoPicker = true
                }) {
                    HStack {
                        Image(systemName: "photo")
                            .foregroundColor(.white)
                        Text("Choose Photo")
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.7))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                }
            }
        }
    }
    
    private func pickerSection(title: String, selection: Binding<String>, options: [(id: String, name: String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Picker(title, selection: selection) {
                if title == "Select Restaurant" {
                    Text("Home").tag("Home")
                }
                ForEach(options, id: \.id) { option in
                    Text(option.name).tag(option.id)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
            .shadow(radius: 5)
        }
    }
    
    private func stepperSection(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(title): \(value.wrappedValue)")
                .font(.headline)
                .foregroundColor(.white)
            Stepper("", value: value, in: range)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
                .shadow(radius: 5)
        }
    }
    
    private var commentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Write your comment...")
                .font(.headline)
                .foregroundColor(.white)
            TextField("", text: $comment)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(10)
                .shadow(radius: 5)
        }
    }

    private var restaurantSearchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Restaurant")
                .font(.headline)
                .foregroundColor(.white)
            
            if selectedRestaurant.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    // Search field for restaurants
                    TextField("Search for a restaurant...", text: $restaurantSearchText, onEditingChanged: { isEditing in
                        showRestaurantSuggestions = isEditing
                    })
                    .onSubmit {
                        if !restaurantSearchText.trimmingCharacters(in: .whitespaces).isEmpty {
                            // If user hits return without selecting a suggestion, use the typed value.
                            selectedRestaurant = restaurantSearchText
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    
                    // Display suggestions if available
                    if showRestaurantSuggestions, !restaurantSearchSuggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(restaurantSearchSuggestions, id: \.id) { restaurant in
                                Text(restaurant.name)
                                    .padding(8)
                                    .onTapGesture {
                                        // When a suggestion is tapped, set the selection.
                                        selectedRestaurant = restaurant.id
                                        restaurantSearchText = restaurant.name
                                        showRestaurantSuggestions = false
                                    }
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
            } else {
                // Display the selected restaurant and a change button.
                HStack {
                    Text("Selected Restaurant: \(restaurantSearchText)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Button("Change") {
                        selectedRestaurant = ""
                        restaurantSearchText = ""
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var submitButton: some View {
        Button(action: submitReview) {
            Text("Submit Review")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.7))
                .cornerRadius(10)
                .shadow(radius: 5)
        }
        .padding(.vertical)
    }
    
    private func fetchRestaurants() {
        guard let url = URL(string: "http://localhost:3000/search/allRestaurants") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching restaurants: \(error.localizedDescription)")
                return
            }
            if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let restaurants = json.compactMap { restaurant -> (id: String, name: String)? in
                    guard let id = restaurant["_id"] as? String, let name = restaurant["name"] as? String else { return nil }
                    return (id: id, name: name)
                }
                DispatchQueue.main.async {
                    self.restaurantOptions = restaurants
                    if self.selectedRestaurant.isEmpty, let firstRestaurant = restaurants.first {
                        self.selectedRestaurant = firstRestaurant.id
                    }
                }
            } else {
                print("Failed to parse restaurants response.")
            }
        }.resume()
    }
    
    private func fetchDrinks() {
        guard let url = URL(string: "http://localhost:3000/search/allDrinks") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Error fetching drinks: \(error.localizedDescription)")
                return
            }
            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    let drinks = json.compactMap { drink -> (id: String, name: String)? in
                        guard let id = drink["_id"] as? String, let name = drink["name"] as? String else { return nil }
                        return (id: id, name: name)
                    }
                    DispatchQueue.main.async {
                        self.drinkOptions = drinks
                        if self.selectedDrink.isEmpty, let firstDrink = drinks.first {
                            self.selectedDrink = firstDrink.id
                            drinkSearchText = firstDrink.name
                        }
                    }
                } else {
                    print("Failed to parse drinks response.")
                }
            }
        }.resume()
    }
    
    private func submitReview() {
        guard let userId = AuthService.loggedInUserId else {
            alertMessage = "User not logged in."
            showAlert = true
            return
        }
        guard let url = URL(string: "http://localhost:3000/reviews") else { return }
        
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        let parameters: [String: Any?] = [
            "user_id": userId,
            "drink_id": selectedDrink,
            "restaurant_id": selectedRestaurant == "Home" ? nil : selectedRestaurant,
            "rating": rating,
            "comment": comment,
            "impairment_level": impairmentLevel
        ]
        
        for (key, value) in parameters {
            if let value = value {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }
        
        if let photo = selectedPhoto, let imageData = photo.jpegData(compressionQuality: 0.8) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(imageData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.alertMessage = "Error: \(error.localizedDescription)"
                    self.showAlert = true
                }
                return
            }
            DispatchQueue.main.async {
                self.alertMessage = "Review submitted successfully!"
                self.showAlert = true
                self.resetForm()
            }
        }.resume()
    }
    
    private func resetForm() {
        selectedRestaurant = ""
        selectedDrink = ""
        rating = 1
        impairmentLevel = 1
        comment = ""
        selectedPhoto = nil
        drinkSearchText = ""
        showDrinkSuggestions = false
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

struct CreateReviewView_Preview: PreviewProvider {
    static var previews: some View {
        CreateReviewView()
    }
}
