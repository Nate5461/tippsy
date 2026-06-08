//
//  Mapcore.swift
//  Tippsy
//
//  Created by Nathan Bissett on 2025-03-12.
//

import SwiftUI
import MapKit
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var locationManager = CLLocationManager()
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 43.00453, longitude: -81.22627), // Default to Aceb
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            DispatchQueue.main.async {
                self.region.center = location.coordinate
            }
        }
    }
}

struct IdentifiableMapItem: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
}

struct MapSearchView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var bars: [IdentifiableMapItem] = []
    @Binding var selectedRestaurant: String
    
    var body: some View {
        VStack {
            Map(coordinateRegion: $locationManager.region, showsUserLocation: true, annotationItems: bars) { bar in
                MapAnnotation(coordinate: bar.mapItem.placemark.coordinate) {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.title)
                        Text(bar.mapItem.name ?? "Unknown")
                            .font(.caption)
                            .fixedSize()
                    }
                }
            }
            .frame(height: 300)
            .onAppear(perform: fetchNearbyBars)
            
            List(bars) { bar in
                Button(action: {
                    selectedRestaurant = bar.mapItem.name ?? "Unknown"
                }) {
                    Text(bar.mapItem.name ?? "Unknown")
                }
            }
        }
    }
    
    func fetchNearbyBars() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "bar"
        request.resultTypes = .pointOfInterest
        request.region = locationManager.region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let response = response {
                DispatchQueue.main.async {
                    bars = response.mapItems.map { IdentifiableMapItem(mapItem: $0) }
                }
            }
        }
    }
}

struct MapSearchView_Previews: PreviewProvider {
    static var previews: some View {
        MapSearchView(selectedRestaurant: .constant(""))
    }
}
