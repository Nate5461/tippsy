//
//  IngredientPickerSheet.swift
//  Tippsy
//
//  Searchable ingredient picker used by Create Recipe and My Bar.
//  Searches the official catalogue + the user's custom ingredients, with
//  kind filter chips and an inline "add your own" path for anything missing.
//

import SwiftUI

struct IngredientPickerSheet: View {
    /// Restricts the picker to one kind (e.g. "garnish" for the garnish
    /// sub-section): the chips disappear and "add your own" pins the kind.
    var lockedKind: String? = nil
    let onSelect: (Ingredient) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedKind: String? // nil = all
    @State private var results: [Ingredient] = []
    @State private var hasLoaded = false
    @State private var searchDebounce: DispatchWorkItem?

    // "Add your own" form
    @State private var showCreateForm = false
    @State private var newName = ""
    @State private var newKind = "spirit"
    @State private var newAbvText = ""
    @State private var isCreating = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchBar
                if lockedKind == nil {
                    kindChips
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(results) { ingredient in
                            ingredientRow(ingredient)
                        }

                        if hasLoaded {
                            addYourOwnButton
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .padding(.top, 12)
            .barBackground()
            .navigationTitle(lockedKind == "garnish" ? "Add Garnish" : "Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showCreateForm) {
                createIngredientForm
                    .presentationDetents([.medium])
            }
            .alert("Ingredient", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .onAppear {
                if let lockedKind {
                    selectedKind = lockedKind
                    newKind = lockedKind
                }
                fetch()
            }
        }
    }

    // MARK: - Pieces

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            TextField(
                "Search ingredients...",
                text: $searchText,
                prompt: Text("Search ingredients...").foregroundColor(.white.opacity(0.6))
            )
            .foregroundColor(.white)
            .tint(.white)
            .autocorrectionDisabled()
        }
        .padding()
        .background(.white.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .onChange(of: searchText) { _, _ in
            debounceFetch()
        }
    }

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                kindChip("All", value: nil)
                ForEach(IngredientKind.ordered, id: \.code) { kind in
                    kindChip(kind.label, value: kind.code)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func kindChip(_ label: String, value: String?) -> some View {
        Button {
            selectedKind = value
            fetch()
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    if selectedKind == value {
                        LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                    } else {
                        Color.white.opacity(0.15)
                    }
                }
                .clipShape(Capsule())
        }
    }

    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        Button {
            onSelect(ingredient)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(ingredient.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                        if ingredient.custom {
                            Text("custom")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    Text(IngredientKind.label(for: ingredient.kind))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                if ingredient.abv > 0 {
                    Text("\(formattedAbv(ingredient.abv))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frostedCard()
        }
        .buttonStyle(.plain)
    }

    private var addYourOwnButton: some View {
        Button {
            newName = searchText
            showCreateForm = true
        } label: {
            HStack {
                Image(systemName: "plus.circle")
                Text("Can't find it? Add your own")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.orange)
            .padding(.vertical, 12)
        }
    }

    private var createIngredientForm: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    frostedTextField("Name", text: $newName)

                    if lockedKind == nil {
                        HStack {
                            Text("Kind")
                                .foregroundColor(.white)
                            Spacer()
                            Picker("Kind", selection: $newKind) {
                                ForEach(IngredientKind.ordered, id: \.code) { kind in
                                    Text(kind.label).tag(kind.code)
                                }
                            }
                            .tint(.orange)
                        }
                        .frostedCard()
                    }

                    frostedTextField("ABV % (optional)", text: $newAbvText)
                        .keyboardType(.decimalPad)

                    Button(action: createIngredient) {
                        if isCreating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Add Ingredient")
                        }
                    }
                    .buttonStyle(GradientCapsuleButtonStyle())
                    .disabled(isCreating || newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .barBackground()
            .navigationTitle("New Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showCreateForm = false }
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formattedAbv(_ abv: Double) -> String {
        abv.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(abv))
            : String(format: "%.1f", abv)
    }

    private func debounceFetch() {
        searchDebounce?.cancel()
        let task = DispatchWorkItem { fetch() }
        searchDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func fetch() {
        IngredientService.searchIngredients(query: searchText, kind: selectedKind) { ingredients in
            results = ingredients
            hasLoaded = true
        }
    }

    private func createIngredient() {
        let abv = Double(newAbvText.replacingOccurrences(of: ",", with: "."))
        isCreating = true
        IngredientService.createIngredient(
            name: newName.trimmingCharacters(in: .whitespaces),
            kind: newKind,
            abv: abv
        ) { result in
            isCreating = false
            switch result {
            case .success(let ingredient):
                showCreateForm = false
                onSelect(ingredient)
                dismiss()
            case .failure(let error):
                alertMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
}
