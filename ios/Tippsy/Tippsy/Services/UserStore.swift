//
//  UserStore.swift
//  Tippsy
//

import Combine

class UserStore: ObservableObject {
    @Published var isLoggedIn: Bool
    @Published var userId: String?
    @Published var username: String?
    @Published var profilePictureUrl: String?

    init() {
        isLoggedIn = TokenStore.read() != nil
    }

    func login(userId: String, username: String) {
        self.userId = userId
        self.username = username
        isLoggedIn = true
    }

    func logout() {
        userId = nil
        username = nil
        profilePictureUrl = nil
        TokenStore.delete()
        isLoggedIn = false
    }
}
