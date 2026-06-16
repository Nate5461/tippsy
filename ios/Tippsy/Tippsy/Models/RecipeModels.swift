//
//  RecipeModels.swift
//  Tippsy
//
//  Codable models for the recipe-domain API: ingredients (with brand
//  hierarchy + ABV), measurement units, recipes with structured ingredient
//  lines, the user's bar, and recipe reviews. JSON keys are camelCase and
//  match the field names directly, so no key decoding strategy is needed.
//

import Foundation

struct Ingredient: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let kind: String
    let parentId: String?
    let abv: Double
    let description: String?
    let imageUrl: String?
    let custom: Bool
}

// Named MeasureUnit to avoid colliding with Foundation's Unit.
struct MeasureUnit: Codable, Identifiable, Hashable {
    let code: String
    let name: String
    let abbrev: String
    let kind: String // "volume" or "count"
    let mlEquiv: Double?

    var id: String { code }
}

// barItemDTO embeds the ingredient fields flat alongside addedAt.
struct BarItem: Codable, Identifiable {
    let id: String
    let name: String
    let kind: String
    let parentId: String?
    let abv: Double
    let description: String?
    let imageUrl: String?
    let custom: Bool
    let addedAt: String
}

struct Measure: Codable, Hashable {
    let metric: String
    let imperial: String
}

struct RecipeLine: Codable, Identifiable, Hashable {
    let position: Int
    let ingredientId: String
    let ingredientName: String
    let ingredientKind: String
    let abv: Double
    let amount: Double?
    let unit: String?
    let note: String?
    let optional: Bool
    let garnish: Bool
    let display: Measure

    var id: Int { position }
}

struct RecipeSummary: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let method: String
    let glass: String // glass_types slug
    let glassName: String
    let source: String // "official" or "community"
    let authorId: String?
    let authorName: String?
    let attribution: String?
    let parentRecipeId: String? // set = modified variant of that recipe
    let parentRecipeName: String?
    let sweetness: Int?
    let estAbv: Double?
    let strength: Int // 1–5; 0 = unknown
    let imageUrl: String?
    let averageRating: Double
    let totalReviews: Int
    let createdAt: String
}

struct RecipeDetail: Codable, Identifiable, Hashable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let method: String
    let glass: String
    let glassName: String
    let source: String
    let authorId: String?
    let authorName: String?
    let attribution: String?
    let parentRecipeId: String?
    let parentRecipeName: String?
    let sweetness: Int?
    let estAbv: Double?
    let strength: Int
    let imageUrl: String?
    let averageRating: Double
    let totalReviews: Int
    let createdAt: String
    let instructions: String?
    let ingredients: [RecipeLine]
}

// The recipe-domain review shape (camelCase). A nil rating is a bare log
// ("I made this") rather than a scored review.
struct RecipeReview: Codable, Identifiable {
    let id: String
    let recipeName: String
    let rating: Int?
    let comment: String?
    let impairmentLevel: Int?
    let photoUrl: String?
    let userId: String
    let username: String
    let createdAt: String
}

struct GlassType: Codable, Identifiable, Hashable {
    let slug: String
    let name: String

    var id: String { slug }
}

enum RecipeMethod {
    static let all = ["shaken", "stirred", "built", "blended", "other"]
}

// Display metadata for the 14 ingredient kinds, in menu/grouping order.
enum IngredientKind {
    static let ordered: [(code: String, label: String)] = [
        ("spirit", "Spirits"),
        ("liqueur", "Liqueurs"),
        ("fortified_wine", "Fortified Wines"),
        ("wine", "Wines"),
        ("beer_cider", "Beer & Cider"),
        ("bitters", "Bitters"),
        ("juice", "Juices"),
        ("syrup", "Syrups"),
        ("soda_mixer", "Sodas & Mixers"),
        ("dairy_egg", "Dairy & Egg"),
        ("fruit", "Fruits"),
        ("herb_spice", "Herbs & Spices"),
        ("garnish", "Garnishes"),
        ("other", "Other"),
    ]

    static func label(for code: String) -> String {
        ordered.first { $0.code == code }?.label ?? code.capitalized
    }

    static func sortIndex(for code: String) -> Int {
        ordered.firstIndex { $0.code == code } ?? ordered.count
    }

    /// SF Symbol used as the category icon on My Bar section headers, browse
    /// tiles, and bottle-card placeholders. Cosmetic and intentionally kept in
    /// one place — swap these for bundled bottle/category artwork later without
    /// touching any views.
    static func icon(for code: String) -> String {
        switch code {
        case "spirit":         return "flame.fill"
        case "liqueur":        return "drop.fill"
        case "fortified_wine": return "wineglass"
        case "wine":           return "wineglass"
        case "beer_cider":     return "mug.fill"
        case "bitters":        return "eyedropper.halffull"
        case "juice":          return "cup.and.saucer.fill"
        case "syrup":          return "drop.triangle.fill"
        case "soda_mixer":     return "sparkles"
        case "dairy_egg":      return "oval.portrait.fill"
        case "fruit":          return "leaf.fill"
        case "herb_spice":     return "leaf"
        case "garnish":        return "leaf.circle.fill"
        case "other":          return "questionmark.circle.fill"
        default:               return "wineglass"
        }
    }

    // Kinds that pour as liquid — these measure in volume units only.
    static let liquid: Set<String> = [
        "spirit", "liqueur", "fortified_wine", "wine", "beer_cider",
        "bitters", "juice", "syrup", "soda_mixer",
    ]
}
