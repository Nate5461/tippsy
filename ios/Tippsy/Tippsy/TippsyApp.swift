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
    @State private var isLoggedIn = false

    var body: some Scene {
        WindowGroup {
            if isLoggedIn {
                MainTabView(isLoggedIn: $isLoggedIn, viewModel: userViewModel)
            } else {
                LoginOrRegisterView(isLoggedIn: $isLoggedIn)
            }
        }
    }
}
