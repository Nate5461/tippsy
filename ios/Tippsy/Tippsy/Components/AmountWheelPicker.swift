//
//  AmountWheelPicker.swift
//  Tippsy
//
//  Scroll-wheel amount entry for recipe lines. Each unit has its own range
//  and step (0.25 oz, 5 ml, whole dashes, ...); a prefilled off-step value is
//  inserted into the options so existing recipes round-trip unchanged.
//

import SwiftUI

struct AmountWheelPicker: View {
    let unit: MeasureUnit?
    @Binding var amount: Double

    var body: some View {
        Picker("Amount", selection: $amount) {
            ForEach(Self.options(for: unit, including: amount), id: \.self) { value in
                Text(Self.label(for: value))
                    .foregroundColor(.white)
                    .tag(value)
            }
        }
        .pickerStyle(.wheel)
    }

    // MARK: - Per-unit steps

    private struct Steps {
        let min: Double
        let max: Double
        let step: Double
        let defaultValue: Double
    }

    private static let stepsByUnit: [String: Steps] = [
        "oz":       Steps(min: 0.25, max: 6, step: 0.25, defaultValue: 1.5),
        "ml":       Steps(min: 5, max: 200, step: 5, defaultValue: 45),
        "cl":       Steps(min: 0.5, max: 20, step: 0.5, defaultValue: 4.5),
        "tsp":      Steps(min: 0.5, max: 6, step: 0.5, defaultValue: 1),
        "barspoon": Steps(min: 0.5, max: 6, step: 0.5, defaultValue: 1),
        "tbsp":     Steps(min: 0.5, max: 4, step: 0.5, defaultValue: 1),
        "dash":     Steps(min: 1, max: 10, step: 1, defaultValue: 2),
        "drop":     Steps(min: 1, max: 10, step: 1, defaultValue: 2),
        "splash":   Steps(min: 1, max: 4, step: 1, defaultValue: 1),
        "top":      Steps(min: 1, max: 4, step: 1, defaultValue: 1),
    ]

    private static func steps(for unit: MeasureUnit?) -> Steps {
        if let unit, let steps = stepsByUnit[unit.code] {
            return steps
        }
        // Future units fall back by kind.
        if unit?.kind == "volume" {
            return Steps(min: 0.25, max: 10, step: 0.25, defaultValue: 1)
        }
        return Steps(min: 1, max: 12, step: 1, defaultValue: 1)
    }

    static func defaultAmount(for unit: MeasureUnit?) -> Double {
        steps(for: unit).defaultValue
    }

    /// The wheel's values for a unit, with `current` spliced in when it falls
    /// off-step so prefilled recipes show their stored amount verbatim.
    static func options(for unit: MeasureUnit?, including current: Double? = nil) -> [Double] {
        let s = steps(for: unit)
        // Integer stepping avoids floating-point drift in the tags.
        let count = Int(((s.max - s.min) / s.step).rounded()) + 1
        var values = (0..<count).map { s.min + Double($0) * s.step }
        if let current, current > 0, !values.contains(current) {
            values.append(current)
            values.sort()
        }
        return values
    }

    /// Snaps a value carried over from another unit onto this unit's wheel.
    static func nearestOption(to value: Double, for unit: MeasureUnit?) -> Double {
        options(for: unit).min { abs($0 - value) < abs($1 - value) } ?? defaultAmount(for: unit)
    }

    /// Renders amounts the way a recipe card would: quarters as fractions
    /// ("1 ¾"), everything else trimmed of trailing zeros.
    static func label(for value: Double) -> String {
        let whole = Int(value)
        let fraction = value - Double(whole)
        let glyph: String?
        switch fraction {
        case 0.25: glyph = "¼"
        case 0.5: glyph = "½"
        case 0.75: glyph = "¾"
        case 0: glyph = nil
        default:
            return String(format: "%g", value)
        }
        if let glyph {
            return whole == 0 ? glyph : "\(whole) \(glyph)"
        }
        return String(whole)
    }
}
