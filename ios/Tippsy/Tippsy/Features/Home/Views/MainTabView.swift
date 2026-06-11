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
                    Image(systemName: "house")
                }

            DiscoverView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                }

            CreateReviewView()
                .tabItem {
                    Image(systemName: "pencil")
                }

            MyBarView()
                .tabItem {
                    Image(systemName: "waterbottle")
                }

            ProfileView(viewModel: viewModel, isLoggedIn: $isLoggedIn) // Pass viewModel here
                .tabItem {
                    Image(systemName: "person")
                }
        }
    }
}
