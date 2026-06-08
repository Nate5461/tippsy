import SwiftUI
import MapKit

struct DiscoverView: View {
    struct City {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    let cities = [
        City(name: "San Francisco", latitude: 37.7749, longitude: -122.4194),
        City(name: "London", latitude: 42.9849, longitude: -81.2453),
        City(name: "Toronto", latitude: 43.6532, longitude: -79.3832)
    ]

    enum SearchCategory {
        case map, users, drinks
    }

    @State private var searchCategory: SearchCategory = .map
    @State private var selectedCity = "San Francisco"
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    @State private var venues: [Venue] = []
    @State private var topUsers: [User] = []
    @State private var topDrinks: [Drink] = []
    @State private var searchText = ""

    var filteredVenues: [Venue] {
        if searchText.isEmpty {
            return venues
        }
        return venues.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    categorySelector
                    searchBar
                    if searchCategory == .map {
                        cityPicker
                        mapView
                        venueList
                    } else if searchCategory == .users {
                        userList
                    } else if searchCategory == .drinks {
                        drinkList
                    }
                }
            }
            .navigationTitle("Discover")
            .padding(.top, 10)
            .onAppear {
                fetchData()
            }
        }
    }

    var categorySelector: some View {
        HStack {
            ForEach([("Map", SearchCategory.map), ("Users", SearchCategory.users), ("Drinks", SearchCategory.drinks)], id: \.1) { label, category in
                Button(action: {
                    searchCategory = category
                    fetchData()
                }) {
                    Text(label)
                        .padding()
                        .foregroundColor(.white)
                        .background(
                            searchCategory == category ?
                            AnyView(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing)) :
                            AnyView(Color.gray.opacity(0.2))
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
    }

    var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
        .onChange(of: searchText) { _ in
            if searchCategory == .users || searchCategory == .drinks {
                fetchData()
            }
        }
    }

    var cityPicker: some View {
        Picker("Select City", selection: $selectedCity) {
            ForEach(cities.map { $0.name }, id: \.self) { city in
                Text(city).tag(city)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .padding()
        .onChange(of: selectedCity) { newCity in
            updateRegion(for: newCity)
        }
    }

    var mapView: some View {
        Map(coordinateRegion: $region, annotationItems: filteredVenues) { venue in
            MapMarker(coordinate: venue.coordinate, tint: .blue)
        }
        .frame(height: 300)
        .cornerRadius(10)
        .padding()
        .gesture(
            DragGesture()
                .onEnded { _ in
                    searchVenues()
                }
        )
    }

    var venueList: some View {
        VStack(alignment: .leading) {
            Text("Venues")
                .font(.headline)
                .padding(.leading)

            LazyVStack {
                ForEach(filteredVenues) { venue in
                    NavigationLink(destination: RestaurantView(
                        viewModel: RestaurantViewModel(),
                        restaurantName: venue.name
                    )) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(venue.name)
                                    .font(.headline)
                                Text(venue.type)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    var userList: some View {
        VStack(alignment: .leading) {
            Text("Users")
                .font(.headline)
                .padding(.leading)

            LazyVStack {
                ForEach(topUsers) { user in
                    NavigationLink(destination: OtherUserProfileView(viewModel: UserViewModel(user: user, isFollowing: isFollowingUser(user)))) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.username)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(10)
                        .shadow(radius: 2)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func isFollowingUser(_ user: User) -> Bool {
        guard let loggedInUserId = AuthService.loggedInUserId else { return false }
        return user.followers.contains { $0.id == loggedInUserId }
    }

    var drinkList: some View {
        VStack(alignment: .leading) {
            Text("Drinks")
                .font(.headline)
                .padding(.leading)

            LazyVStack {
                ForEach(topDrinks) { drink in
                    VStack(alignment: .leading) {
                        Text(drink.name)
                            .font(.headline)
                        Text(drink.category)
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        HStack {
                            Text("Average Rating: \(String(format: "%.1f", drink.averageRating ?? 0.0))")
                                .font(.subheadline)
                                .foregroundColor(.blue)

                            Text("Reviews: \(drink.totalReviews ?? 0)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .leading, endPoint: .trailing))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                }
            }
            .padding(.horizontal)
        }
    }

    func fetchData() {
        switch searchCategory {
        case .map:
            searchVenues()
        case .users:
            SearchService.fetchTopUsers(query: searchText) { users in
                DispatchQueue.main.async {
                    self.topUsers = searchText.isEmpty ? Array(users.prefix(5)) : users
                }
            }
        case .drinks:
            SearchService.fetchTopDrinks(query: searchText) { drinks in
                DispatchQueue.main.async {
                    self.topDrinks = searchText.isEmpty ? Array(drinks.prefix(5)) : drinks
                }
            }
        }
    }

    private func updateRegion(for cityName: String) {
        if let city = cities.first(where: { $0.name == cityName }) {
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: city.latitude,
                    longitude: city.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            searchVenues()
        }
    }

    func searchVenues() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "bars"
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response else { return }

            var newVenues = response.mapItems.map { item in
                Venue(
                    name: item.name ?? "Unknown",
                    type: "Bar",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
            }

            if self.selectedCity == "London" {
                let barX = Venue(
                    name: "BarX",
                    type: "Bar",
                    latitude: 42.9849,
                    longitude: -81.2453
                )
                newVenues.append(barX)
            }

            DispatchQueue.main.async {
                self.venues = newVenues
            }
        }
    }
}

struct Venue: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct DiscoverView_Previews: PreviewProvider {
    static var previews: some View {
        DiscoverView()
    }
}
