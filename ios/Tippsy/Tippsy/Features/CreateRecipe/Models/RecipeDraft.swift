//
//  RecipeDraft.swift
//  Tippsy
//
//  Editable working copy of a recipe for the log/create flow. A draft built
//  from an existing RecipeDetail doubles as the dirty-tracking snapshot:
//  comparing the live draft against it decides whether submitting just logs
//  the original or publishes a modified community variant.
//

import Foundation

struct DraftLine: Identifiable, Equatable {
    let id = UUID()
    var ingredientId: String
    var ingredientName: String
    var ingredientKind: String
    var amount: Double?
    var unitCode: String?
    var note: String = ""
    var isGarnish: Bool = false

    /// Picker-added line: liquids start at the wheel default for the user's
    /// preferred volume unit; garnish starts at 1 piece.
    init(ingredient: Ingredient, isGarnish: Bool, measurePref: String, units: [MeasureUnit]) {
        ingredientId = ingredient.id
        ingredientName = ingredient.name
        ingredientKind = ingredient.kind
        self.isGarnish = isGarnish
        let code = isGarnish ? "piece" : (measurePref == "imperial" ? "oz" : "ml")
        let unit = units.first { $0.code == code }
        unitCode = unit?.code ?? code
        amount = isGarnish ? 1 : AmountWheelPicker.defaultAmount(for: unit)
    }

    /// Prefilled line: amount/unit verbatim from storage (never converted to
    /// the user's measure preference) so an untouched draft compares equal.
    init(from line: RecipeLine) {
        ingredientId = line.ingredientId
        ingredientName = line.ingredientName
        ingredientKind = line.ingredientKind
        amount = line.amount
        unitCode = line.unit
        note = (line.note ?? "").trimmingCharacters(in: .whitespaces)
        isGarnish = line.garnish
    }

    // The id is identity, not content — two lines with the same ingredient
    // and measure are the same recipe line.
    static func == (lhs: DraftLine, rhs: DraftLine) -> Bool {
        lhs.ingredientId == rhs.ingredientId
            && lhs.amount == rhs.amount
            && lhs.unitCode == rhs.unitCode
            && lhs.note.trimmingCharacters(in: .whitespaces) == rhs.note.trimmingCharacters(in: .whitespaces)
            && lhs.isGarnish == rhs.isGarnish
    }
}

struct RecipeDraft: Equatable {
    var description = ""
    var method = "stirred"
    var glassSlug = ""
    var sweetness: Int?
    var instructions = ""
    var lines: [DraftLine] = []

    init() {}

    init(from detail: RecipeDetail) {
        description = detail.description ?? ""
        method = detail.method
        glassSlug = detail.glass
        sweetness = detail.sweetness
        instructions = detail.instructions ?? ""
        lines = detail.ingredients.map(DraftLine.init(from:))
    }

    var regularLines: [DraftLine] { lines.filter { !$0.isGarnish } }
    var garnishLines: [DraftLine] { lines.filter { $0.isGarnish } }

    static func == (lhs: RecipeDraft, rhs: RecipeDraft) -> Bool {
        lhs.description.trimmingCharacters(in: .whitespaces) == rhs.description.trimmingCharacters(in: .whitespaces)
            && lhs.method == rhs.method
            && lhs.glassSlug == rhs.glassSlug
            && lhs.sweetness == rhs.sweetness
            && lhs.instructions.trimmingCharacters(in: .whitespaces) == rhs.instructions.trimmingCharacters(in: .whitespaces)
            && lhs.lines == rhs.lines
    }

    /// The POST /recipes body. Garnish ordering is enforced server-side; the
    /// lines go up in display order.
    func payload(name: String, parentRecipeId: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "method": method,
            "glass": glassSlug,
        ]
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        if !trimmedDescription.isEmpty { payload["description"] = trimmedDescription }
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespaces)
        if !trimmedInstructions.isEmpty { payload["instructions"] = trimmedInstructions }
        if let sweetness { payload["sweetness"] = sweetness }
        if let parentRecipeId { payload["parentRecipeId"] = parentRecipeId }

        payload["ingredients"] = lines.map { line -> [String: Any] in
            var entry: [String: Any] = [
                "ingredientId": line.ingredientId,
                "garnish": line.isGarnish,
            ]
            if let amount = line.amount { entry["amount"] = amount }
            if let unitCode = line.unitCode { entry["unit"] = unitCode }
            let trimmedNote = line.note.trimmingCharacters(in: .whitespaces)
            if !trimmedNote.isEmpty { entry["note"] = trimmedNote }
            return entry
        }
        return payload
    }
}
