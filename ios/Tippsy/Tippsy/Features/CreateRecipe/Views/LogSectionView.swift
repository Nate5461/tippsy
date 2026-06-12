//
//  LogSectionView.swift
//  Tippsy
//
//  The "log it" portion of the editor: optional star rating (tap the same
//  star again to clear — a bare log is valid), a comment, and the
//  impairment stepper.
//

import SwiftUI

struct LogSectionView: View {
    @Binding var rating: Int?
    @Binding var comment: String
    @Binding var impairment: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { i in
                        Image(systemName: i <= (rating ?? 0) ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(.yellow)
                            .onTapGesture {
                                rating = rating == i ? nil : i
                            }
                    }
                }
                Text(rating == nil ? "Tap to rate — or just log it" : "Tap the same star to clear")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            TextField(
                "Say something about it",
                text: $comment,
                prompt: Text("Say something about it").foregroundColor(.white.opacity(0.6)),
                axis: .vertical
            )
            .lineLimit(2...5)
            .foregroundColor(.white)
            .tint(.white)
            .padding()
            .background(.white.opacity(0.1))
            .cornerRadius(10)

            HStack {
                Text("Impairment level: \(impairment)")
                    .font(.subheadline)
                    .foregroundColor(.white)
                Spacer()
                Stepper("", value: $impairment, in: 1...5)
                    .labelsHidden()
            }
        }
        .frostedCard()
    }
}
