//
//  MainTabView.swift
//  Tippsy
//
//  Created by Nathan Bissett on 2024-12-04.
// Edited by Lucas Carter on 2025-03-12

import SwiftUI

struct MainTabView: View {
    @Binding var isLoggedIn: Bool // Bind to login status from TippsyApp
    @ObservedObject var viewModel: UserViewModel // Add the viewModel parameter
    
    var body: some View {
        TabView {
            HomeView(viewModel: viewModel , isLoggedIn: $isLoggedIn)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            DiscoverView()
                .tabItem {
                    Label("Discover", systemImage: "magnifyingglass")
                }
            
            ProfileView(viewModel: viewModel, isLoggedIn: $isLoggedIn) // Pass viewModel here
                .tabItem {
                    Label("Profile", systemImage: "person")
                }

            CreateReviewView()
                .tabItem {
                    Label("Write Review", systemImage: "pencil")
                }
        }
    }
}
