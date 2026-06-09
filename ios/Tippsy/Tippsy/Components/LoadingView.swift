//
//  LoadingView.swift
//  Tippsy
//
//  Animated splash shown while the app starts up.
//

import SwiftUI

struct LoadingView: View {
    @State private var shifted = false

    var body: some View {
        GeometryReader { proxy in
            Image("Loading")
                .resizable()
                .scaledToFit()
                .frame(width: 80)
                .rotationEffect(.degrees(45))          
                .offset(
                    x: shifted ? -20 : 20,               
                    y: shifted ? 20 : -20
                )
                .animation(
                    .easeInOut(duration: 0.4).repeatForever(autoreverses: true),
                    value: shifted
                )
                .position(x: proxy.size.width / 2, y: proxy.size.height / 3)
        }
        .background(Color("BackgroundColour"))
        .ignoresSafeArea()
        .onAppear { shifted = true }
    }
}

#Preview {
    LoadingView()
}
