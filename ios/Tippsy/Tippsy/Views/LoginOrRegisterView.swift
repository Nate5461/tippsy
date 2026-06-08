//
//  LoginOrRegisterView.swift
//  Tippsy
//
//  Created by Joelle Ishimwe on 2024-12-22.
//

import SwiftUI

struct LoginOrRegisterView: View {
    @Binding var isLoggedIn: Bool // Bind to login status from TippsyApp

    var body: some View {
        NavigationStack {
            ZStack {
                Image("bar_background") 
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(
                        Color.black.opacity(0.4) 
                    )

                VStack(spacing: 30) {
                    Spacer()


                    Image(systemName: "wineglass.fill") 
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.white)
                        .shadow(radius: 10)

                    // Welcome Text
                    VStack(spacing: 10) {
                        Text("Welcome to Tippsy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Discover, rate, and share your favorite drinks!")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 30)
                    }

                    Spacer()

                    // Login Button
                    NavigationLink(destination: LoginView(isLoggedIn: $isLoggedIn)) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.white)
                            Text("Login")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange, Color.red]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 40)

                    // Register Button
                    NavigationLink(destination: RegistrationView(isLoggedIn: $isLoggedIn)) {
                        HStack {
                            Image(systemName: "pencil")
                                .foregroundColor(.white)
                            Text("Register")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                        .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 40)

                    Spacer()
                }
                .padding()
            }
        }
    }
}

struct LoginOrRegisterView_Previews: PreviewProvider {
    @State static var isLoggedIn = false // State variable for testing

    static var previews: some View {
        LoginOrRegisterView(isLoggedIn: $isLoggedIn) // Pass the dynamic binding
    }
}
