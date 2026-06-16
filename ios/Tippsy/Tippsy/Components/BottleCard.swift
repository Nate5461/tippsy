//
//  BottleCard.swift
//  Tippsy
//
//  A compact "bottle on the shelf" card for the My Bar horizontal scrollers.
//  Shows bottle artwork when available, otherwise a category-icon placeholder
//  (so it reads as intentional until real art is added). Pass `onRemove` to get
//  a corner remove button plus a long-press "Remove" context menu.
//

import SwiftUI

struct BottleCard: View {
    let name: String
    let kind: String
    let imageUrl: String?
    var abv: Double = 0
    var custom: Bool = false
    var onRemove: (() -> Void)? = nil

    private let cardWidth: CGFloat = 104

    var body: some View {
        VStack(spacing: 8) {
            artwork
            VStack(spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 38, alignment: .top)
                if custom {
                    Text("custom")
                        .font(.caption2)
                        .foregroundColor(.orange)
                } else if abv > 0 {
                    Text("\(formattedAbv(abv))% ABV")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .frame(width: cardWidth)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.12))
        .cornerRadius(16)
        .overlay(alignment: .topTrailing) {
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(.black.opacity(0.35))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
            }
        }
        .contextMenu {
            if let onRemove {
                Button(role: .destructive, action: onRemove) {
                    Label("Remove from bar", systemImage: "trash")
                }
            }
        }
    }

    private var artwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(0.08))
            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFit().padding(8)
                } placeholder: {
                    placeholderIcon
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 84, height: 84)
    }

    private var placeholderIcon: some View {
        Image(systemName: IngredientKind.icon(for: kind))
            .font(.system(size: 30))
            .foregroundColor(.white.opacity(0.55))
    }

    private func formattedAbv(_ abv: Double) -> String {
        abv.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(abv))
            : String(format: "%.1f", abv)
    }
}
