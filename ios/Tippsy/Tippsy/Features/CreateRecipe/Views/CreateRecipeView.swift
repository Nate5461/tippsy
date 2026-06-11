//
//  CreateRecipeView.swift
//  Tippsy
//
//  Recipe upload: basics (name, method, glass, sweetness), structured
//  ingredient lines with amounts and units, instructions, and submit.
//

import SwiftUI
import PhotosUI

struct CreateRecipeView: View {
    @ObservedObject var viewModel: UserViewModel

    struct DraftLine: Identifiable {
        let id = UUID()
        var ingredient: Ingredient
        var amount: Double?
        var unit: MeasureUnit?
        var note: String = ""
        var optional: Bool = false
    }

    private static let commonGlasses = ["Coupe", "Rocks", "Highball", "Martini", "Collins", "Flute", "Mug", "Shot"]

    @State private var name = ""
    @State private var description = ""
    @State private var method = "stirred"
    @State private var glass = ""
    @State private var sweetnessEnabled = false
    @State private var sweetness: Double = 5

    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?

    @State private var lines: [DraftLine] = []
    @State private var showIngredientPicker = false
    @State private var editingLineID: UUID?

    @State private var instructions = ""

    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertTitle = "Notice"
    @State private var alertMessage = ""

    private var measurePref: String {
        viewModel.user?.measurePref ?? "metric"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    basicsSection
                    photoSection
                    ingredientsSection
                    instructionsSection

                    Button(action: submit) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Create Recipe")
                        }
                    }
                    .buttonStyle(GradientCapsuleButtonStyle())
                    .disabled(isSubmitting || !isValid)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .barBackground()
            .navigationTitle("Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showIngredientPicker) {
                IngredientPickerSheet { ingredient in
                    let line = DraftLine(ingredient: ingredient)
                    lines.append(line)
                    editingLineID = line.id
                }
            }
            .sheet(item: editingLineBinding) { line in
                RecipeLineEditorSheet(
                    line: line,
                    measurePref: measurePref,
                    onSave: { updated in
                        if let idx = lines.firstIndex(where: { $0.id == updated.id }) {
                            lines[idx] = updated
                        }
                    },
                    onMove: { id, direction in
                        moveLine(id: id, direction: direction)
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !lines.isEmpty && lines.count <= 30
    }

    // Bridges editingLineID to the sheet(item:) API.
    private var editingLineBinding: Binding<DraftLine?> {
        Binding(
            get: { lines.first { $0.id == editingLineID } },
            set: { if $0 == nil { editingLineID = nil } }
        )
    }

    // MARK: - Sections

    private var basicsSection: some View {
        VStack(spacing: 12) {
            frostedTextField("Recipe name", text: $name)

            frostedTextField("Description (optional)", text: $description)

            VStack(alignment: .leading, spacing: 8) {
                Text("Method")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                HStack(spacing: 4) {
                    ForEach(RecipeMethod.all, id: \.self) { m in
                        Button {
                            method = m
                        } label: {
                            Text(m.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background {
                                    if method == m {
                                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                    } else {
                                        Color.white.opacity(0.15)
                                    }
                                }
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                frostedTextField("Glass (optional)", text: $glass)

                Menu {
                    ForEach(Self.commonGlasses, id: \.self) { g in
                        Button(g) { glass = g }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .foregroundColor(.white)
                        .padding()
                        .background(.white.opacity(0.15))
                        .cornerRadius(12)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $sweetnessEnabled) {
                    Text(sweetnessEnabled ? "Sweetness: \(Int(sweetness))/10" : "Set sweetness")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                .tint(.orange)

                if sweetnessEnabled {
                    Slider(value: $sweetness, in: 0...10, step: 1)
                        .tint(.orange)
                    HStack {
                        Text("Dry").font(.caption2).foregroundColor(.white.opacity(0.6))
                        Spacer()
                        Text("Sweet").font(.caption2).foregroundColor(.white.opacity(0.6))
                    }
                }
            }
            .frostedCard()
        }
    }

    private var photoSection: some View {
        // The backend has no recipe image upload endpoint yet; the picker is
        // a placeholder and the chosen image is not sent with the recipe.
        PhotosPicker(selection: $photoItem, matching: .images) {
            HStack(spacing: 12) {
                if let photoImage {
                    Image(uiImage: photoImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 56, height: 56)
                        .background(.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add a photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text("Photo upload coming soon — not saved yet")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            }
            .frostedCard()
        }
        .onChange(of: photoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoImage = UIImage(data: data)
                }
            }
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ingredients")
                .font(.headline)
                .foregroundColor(.white)

            ForEach(lines) { line in
                lineRow(line)
            }

            Button {
                showIngredientPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add ingredient")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
            }
            .padding(.top, 2)
        }
        .frostedCard()
    }

    private func lineRow(_ line: DraftLine) -> some View {
        Button {
            editingLineID = line.id
        } label: {
            HStack(spacing: 10) {
                Text(amountLabel(line))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
                    .frame(width: 76, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(line.ingredient.name)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        if line.optional {
                            Text("(optional)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    if !line.note.isEmpty {
                        Text(line.note)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                Button {
                    lines.removeAll { $0.id == line.id }
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.white.opacity(0.1))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions")
                .font(.headline)
                .foregroundColor(.white)

            TextField(
                "How to make it (optional)",
                text: $instructions,
                prompt: Text("How to make it (optional)").foregroundColor(.white.opacity(0.6)),
                axis: .vertical
            )
            .lineLimit(4...10)
            .foregroundColor(.white)
            .tint(.white)
        }
        .frostedCard()
    }

    // MARK: - Helpers

    private func amountLabel(_ line: DraftLine) -> String {
        guard let amount = line.amount else { return "to taste" }
        let amountText = amount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(amount))
            : String(format: "%.2g", amount)
        if let unit = line.unit {
            return "\(amountText) \(unit.abbrev)"
        }
        return amountText
    }

    private func moveLine(id: UUID, direction: Int) {
        guard let idx = lines.firstIndex(where: { $0.id == id }) else { return }
        let newIdx = idx + direction
        guard newIdx >= 0 && newIdx < lines.count else { return }
        lines.swapAt(idx, newIdx)
    }

    private func submit() {
        var payload: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespaces),
            "method": method,
        ]
        let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
        if !trimmedDescription.isEmpty { payload["description"] = trimmedDescription }
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespaces)
        if !trimmedInstructions.isEmpty { payload["instructions"] = trimmedInstructions }
        let trimmedGlass = glass.trimmingCharacters(in: .whitespaces)
        if !trimmedGlass.isEmpty { payload["glass"] = trimmedGlass }
        if sweetnessEnabled { payload["sweetness"] = Int(sweetness) }

        payload["ingredients"] = lines.map { line -> [String: Any] in
            var entry: [String: Any] = [
                "ingredientId": line.ingredient.id,
                "optional": line.optional,
            ]
            if let amount = line.amount { entry["amount"] = amount }
            if let unit = line.unit { entry["unit"] = unit.code }
            let trimmedNote = line.note.trimmingCharacters(in: .whitespaces)
            if !trimmedNote.isEmpty { entry["note"] = trimmedNote }
            return entry
        }

        isSubmitting = true
        RecipeService.createRecipe(payload: payload) { result in
            isSubmitting = false
            switch result {
            case .success(let recipe):
                alertTitle = "Recipe Created"
                alertMessage = "\"\(recipe.name)\" is now live in the community."
                showAlert = true
                resetForm()
            case .failure(let error):
                alertTitle = "Notice"
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }

    private func resetForm() {
        name = ""
        description = ""
        method = "stirred"
        glass = ""
        sweetnessEnabled = false
        sweetness = 5
        photoItem = nil
        photoImage = nil
        lines = []
        instructions = ""
    }
}

// MARK: - Line editor sheet

private struct RecipeLineEditorSheet: View {
    @State var line: CreateRecipeView.DraftLine
    let measurePref: String
    let onSave: (CreateRecipeView.DraftLine) -> Void
    let onMove: (UUID, Int) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var toTaste: Bool
    @State private var amountText: String
    @State private var units: [MeasureUnit] = []

    init(line: CreateRecipeView.DraftLine, measurePref: String, onSave: @escaping (CreateRecipeView.DraftLine) -> Void, onMove: @escaping (UUID, Int) -> Void) {
        _line = State(initialValue: line)
        self.measurePref = measurePref
        self.onSave = onSave
        self.onMove = onMove
        _toTaste = State(initialValue: line.amount == nil)
        if let amount = line.amount {
            _amountText = State(initialValue: amount.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amount))
                : String(amount))
        } else {
            _amountText = State(initialValue: "")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text(line.ingredient.name)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)

                    Toggle(isOn: $toTaste) {
                        Text("To taste / no measure")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .tint(.orange)
                    .frostedCard()

                    if !toTaste {
                        HStack(spacing: 8) {
                            frostedTextField("Amount", text: $amountText)
                                .keyboardType(.decimalPad)

                            Picker("Unit", selection: unitSelection) {
                                Section("Volume") {
                                    ForEach(units.filter { $0.kind == "volume" }) { unit in
                                        Text(unit.abbrev).tag(unit.code as String?)
                                    }
                                }
                                Section("Count") {
                                    ForEach(units.filter { $0.kind == "count" }) { unit in
                                        Text(unit.name).tag(unit.code as String?)
                                    }
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(.orange)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.white.opacity(0.15))
                            .cornerRadius(12)
                        }
                    }

                    frostedTextField("Note, e.g. freshly squeezed (optional)", text: $line.note)

                    Toggle(isOn: $line.optional) {
                        Text("Optional ingredient")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
                    .tint(.orange)
                    .frostedCard()

                    HStack(spacing: 12) {
                        Button {
                            onMove(line.id, -1)
                        } label: {
                            Label("Move up", systemImage: "arrow.up")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Button {
                            onMove(line.id, 1)
                        } label: {
                            Label("Move down", systemImage: "arrow.down")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.white.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

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

    private var unitSelection: Binding<String?> {
        Binding(
            get: { line.unit?.code },
            set: { code in
                line.unit = units.first { $0.code == code }
            }
        )
    }

    private func loadUnits() {
        IngredientService.fetchUnits { fetched in
            units = fetched
            if line.unit == nil {
                let defaultCode = measurePref == "imperial" ? "oz" : "ml"
                line.unit = fetched.first { $0.code == defaultCode } ?? fetched.first
            }
        }
    }

    private func save() {
        if toTaste {
            line.amount = nil
        } else {
            line.amount = Double(amountText.replacingOccurrences(of: ",", with: "."))
        }
        // An empty/invalid amount with the toggle off also means "to taste".
        if line.amount == nil {
            line.unit = nil
        }
        onSave(line)
        dismiss()
    }
}
