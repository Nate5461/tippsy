//
//  TippsyApp.swift
//  Tippsy
//
//  Created by Nathan Bissett on 2024-11-18.
//

import SwiftUI

@main
struct TippsyApp: App {
    @StateObject var userStore = UserStore()
    @StateObject var userViewModel = UserViewModel()
    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    LoadingView()
                        .transition(.opacity)
                        .task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation(.easeInOut(duration: 0.45)) {
                                isLoading = false
                            }
                        }
                } else if userStore.isLoggedIn {
                    MainTabView(isLoggedIn: $userStore.isLoggedIn, viewModel: userViewModel)
                        .transition(.opacity)
                } else {
                    LoginView(isLoggedIn: $userStore.isLoggedIn)
                        .transition(.opacity)
                }
            }
            .environmentObject(userStore)
            .onReceive(NotificationCenter.default.publisher(for: .didReceiveUnauthorized)) { _ in
                AuthService.loggedInUserId = nil
                AuthService.username = nil
                userViewModel.user = nil
                userViewModel.reviews = []
                userViewModel.followingUsers = []
                userStore.logout()
            }
        }
    }
}
