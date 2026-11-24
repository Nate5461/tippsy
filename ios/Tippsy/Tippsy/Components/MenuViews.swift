//
//  MenuViews.swift
//  Tippsy
//
//  Small reusable views for tags and menu rows, used by Discover search results
//  and the menu detail screen.
//

import SwiftUI

/// A horizontally scrolling row of tag pills. Renders nothing when empty.
struct TagChips: View {
    let tags: [Tag]

    var body: some View {
        if !tags.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags) { tag in
                        Text(tag.label)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

/// A frosted row summarizing a user-created menu (list of cocktails).
struct MenuRow: View {
    let menu: MenuSummary

    private var drinkCount: String {
        "\(menu.recipeCount) \(menu.recipeCount == 1 ? "drink" : "drinks")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle.portrait.fill")
                    .foregroundColor(.orange)
                Text(menu.name)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
            Text("by @\(menu.authorName) · \(drinkCount)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            TagChips(tags: menu.tags)
        }
        .frostedCard()
    }
}
