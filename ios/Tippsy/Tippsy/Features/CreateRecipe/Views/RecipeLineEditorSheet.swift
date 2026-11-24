//
//  RecipeLineEditorSheet.swift
//  Tippsy
//
//  Edits one draft line: amount on a scroll wheel (per-unit steps), unit
//  menu (volume-only for liquid ingredients), and a free-text note. Lines
//  prefilled without a measure keep nil unless the wheel is actually moved,
//  so opening and closing an untouched line never marks the draft dirty.
//

import SwiftUI

struct RecipeLineEditorSheet: View {
    @State var line: DraftLine
    let measurePref: String
    let onSave: (DraftLine) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var units: [MeasureUnit] = []
    @State private var selectedUnitCode: String?
    @State private var wheelValue: Double
    @State private var measureTouched: Bool
    @State private var suppressTouch = false
    private let startedUnmeasured: Bool

    init(line: DraftLine, measurePref: String, onSave: @escaping (DraftLine) -> Void) {
        _line = State(initialValue: line)
        self.measurePref = measurePref
        self.onSave = onSave
        _selectedUnitCode = State(initialValue: line.unitCode)
        _wheelValue = State(initialValue: line.amount ?? 1)
        startedUnmeasured = line.amount == nil
        _measureTouched = State(initialValue: false)
    }

    private var selectedUnit: MeasureUnit? {
        units.first { $0.code == selectedUnitCode }
    }

    // Liquids pour; they measure in volume units only.
    private var availableUnits: [MeasureUnit] {
        IngredientKind.liquid.contains(line.ingredientKind)
            ? units.filter { $0.kind == "volume" }
            : units
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(line.ingredientName)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)

                    HStack(spacing: 12) {
                        AmountWheelPicker(unit: selectedUnit, amount: $wheelValue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .clipped()
                            .onChange(of: wheelValue) { _, _ in
                                if suppressTouch {
                                    suppressTouch = false
                                } else {
                                    measureTouched = true
                                }
                            }

                        unitMenu
                    }
                    .frostedCard()

                    if startedUnmeasured && !measureTouched {
                        Text("No measure saved — spin the wheel to set one")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    frostedTextField("Add a note — e.g. freshly squeezed", text: $line.note)

                    Button("Done") {
                        save()
                    }
                    .buttonStyle(GradientCapsuleButtonStyle())
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .barBackground()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadUnits)
        }
    }

    private var unitMenu: some View {
        Menu {
            ForEach(availableUnits) { unit in
                Button(unit.kind == "volume" ? unit.abbrev : unit.name) {
                    switchUnit(to: unit)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedUnit?.abbrev ?? selectedUnitCode ?? "unit")
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.orange)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(.white.opacity(0.15))
            .cornerRadius(12)
        }
    }

    // MARK: - Actions

    private func switchUnit(to unit: MeasureUnit) {
        // Carry the volume across unit systems (1.5 oz -> 45 ml), then snap
        // onto the new unit's wheel steps.
        if let fromMl = selectedUnit?.mlEquiv, let toMl = unit.mlEquiv, toMl > 0 {
            wheelValue = AmountWheelPicker.nearestOption(to: wheelValue * fromMl / toMl, for: unit)
        } else {
            wheelValue = AmountWheelPicker.nearestOption(to: wheelValue, for: unit)
        }
        selectedUnitCode = unit.code
        measureTouched = true
    }

    private func loadUnits() {
        IngredientService.fetchUnits { fetched in
            units = fetched
            if selectedUnitCode == nil && !startedUnmeasured {
                selectedUnitCode = measurePref == "imperial" ? "oz" : "ml"
            }
            // Park the wheel on the unit's default without counting it as a
            // user edit, so an untouched unmeasured line stays unmeasured.
            if startedUnmeasured {
                let parked = AmountWheelPicker.defaultAmount(for: selectedUnit)
                if parked != wheelValue {
                    suppressTouch = true
                    wheelValue = parked
                }
            }
        }
    }

    private func save() {
        // An untouched unmeasured line stays unmeasured.
        if measureTouched || !startedUnmeasured {
            line.amount = wheelValue
            line.unitCode = selectedUnitCode ?? (measurePref == "imperial" ? "oz" : "ml")
        }
        onSave(line)
        dismiss()
    }
}
