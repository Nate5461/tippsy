//
//  Theme.swift
//  Tippsy
//
//  Shared design system: the dark "bar" look used across the app.
//  Frosted translucent fields/cards over the bar_background photo, with
//  orange→red gradient capsule buttons for primary actions.
//

import SwiftUI

extension View {
    /// The standard app background: bar photo dimmed by a dark overlay.
    func barBackground() -> some View {
        background {
            Image("bar_background")
                .resizable()
                .scaledToFill()
                .overlay(Color.black.opacity(0.55))
                .ignoresSafeArea()
        }
    }

    /// Frosted translucent card container for content sections.
    func frostedCard() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.15))
            .cornerRadius(12)
    }
}

@ViewBuilder
func frostedTextField(_ placeholder: String, text: Binding<String>) -> some View {
    TextField(
        placeholder,
        text: text,
        prompt: Text(placeholder).foregroundColor(.white.opacity(0.6))
    )
    .foregroundColor(.white)
    .tint(.white)
    .padding()
    .frame(maxWidth: .infinity)
    .background(.white.opacity(0.15))
    .cornerRadius(12)
}

@ViewBuilder
func frostedSecureField(_ placeholder: String, text: Binding<String>) -> some View {
    SecureField(
        placeholder,
        text: text,
        prompt: Text(placeholder).foregroundColor(.white.opacity(0.6))
    )
    .foregroundColor(.white)
    .tint(.white)
    .padding()
    .frame(maxWidth: .infinity)
    .background(.white.opacity(0.15))
    .cornerRadius(12)
}

/// Primary action button: orange→red gradient capsule with white text.
struct GradientCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
