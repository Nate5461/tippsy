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

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoggedIn {
                    MainTabView(isLoggedIn: $isLoggedIn, viewModel: userViewModel)
                } else {
                    LoginOrRegisterView(isLoggedIn: $isLoggedIn)
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
