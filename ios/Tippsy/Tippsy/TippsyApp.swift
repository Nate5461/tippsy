//
//  TippsyApp.swift
//  Tippsy
//
//  Created by Nathan Bissett on 2024-11-18.
//

import SwiftUI

@main
struct TippsyApp: App {
    @StateObject var userViewModel = UserViewModel()
    @State private var isLoggedIn = TokenStore.read() != nil
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
                } else if isLoggedIn {
                    MainTabView(isLoggedIn: $isLoggedIn, viewModel: userViewModel)
                        .transition(.opacity)
                } else {
                    LoginOrRegisterView(isLoggedIn: $isLoggedIn)
                        .transition(.opacity)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .didReceiveUnauthorized)) { _ in
                TokenStore.delete()
                AuthService.loggedInUserId = nil
                AuthService.username = nil
                isLoggedIn = false
            }
        }
    }
}
