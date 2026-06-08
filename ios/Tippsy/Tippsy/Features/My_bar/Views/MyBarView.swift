//
//  MyBarView.swift
//  Tippsy
//

import SwiftUI

struct MyBarView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wineglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("My Bar")
                .font(.title2)
                .fontWeight(.bold)
            Text("Coming soon")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MyBarView()
}
