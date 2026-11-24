//
//  AddToBarSheet.swift
//  Tippsy
//
//  The My Bar add experience. Browse the most common spirits (and other
//  categories) as tiles, drill into a generic to see its brands with the
//  generic listed first, or search the whole catalogue for the long tail.
//  "Add your own" creates a custom ingredient. Picking anything hands it back
//  via onSelect and dismisses.
//
//  (Create Recipe still uses IngredientPickerSheet — this flow is bar-specific.)
//

import SwiftUI

struct AddToBarSheet: View {
    let onSelect: (Ingredient) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var searchResults: [Ingredient] = []
    @State private var generics: [Ingredient] = []
    @State private var selectedKind = "spirit"
    @State private var searchDebounce: DispatchWorkItem?

    // Categories worth browsing as a grid; the rest are reachable via search.
    private let browseKinds: [(code: String, label: String)] = [
        ("spirit", "Spirits"),
        ("liqueur", "Liqueurs"),
        ("fortified_wine", "Fortified"),
        ("wine", "Wine"),
        ("beer_cider", "Beer"),
        ("soda_mixer", "Mixers"),
    ]
    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchBar

                if isSearching {
                    searchList
                } else {
                    kindChips
                    browseGrid
                }
            }
            .padding(.top, 12)
            .barBackground()
            .navigationTitle("Add to Bar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
            .navigationDestination(for: Ingredient.self) { generic in
                BrandListView(generic: generic, onSelect: pick)
            }
            .onAppear {
                if generics.isEmpty { loadGrid() }
            }
        }
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.6))
            TextField(
                "Search anything…",
                text: $searchText,
                prompt: Text("Search anything…").foregroundColor(.white.opacity(0.6))
            )
            .foregroundColor(.white)
            .tint(.white)
            .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.white.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .onChange(of: searchText) { _, _ in debounceSearch() }
    }

    private var searchList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(searchResults) { ingredient in
                    IngredientPickRow(ingredient: ingredient) { pick(ingredient) }
                }
                if searchResults.isEmpty {
                    Text("No matches. Try a different spelling.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Browse

    private var kindChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(browseKinds, id: \.code) { kind in
                    Button {
                        selectedKind = kind.code
                        loadGrid()
                    } label: {
                        Text(kind.label)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                if selectedKind == kind.code {
                                    LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
                                } else {
                                    Color.white.opacity(0.15)
                                }
                            }
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var browseGrid: some View {
        ScrollView {
            if generics.isEmpty {
                Text("Nothing here yet.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(generics) { generic in
                        NavigationLink(value: generic) {
                            CategoryTile(name: generic.name, kind: generic.kind, imageUrl: generic.imageUrl)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Actions

    private func pick(_ ingredient: Ingredient) {
        onSelect(ingredient)
        dismiss()
    }

    private func loadGrid() {
        IngredientService.fetchTopLevel(kind: selectedKind) { generics = $0 }
    }

    private func debounceSearch() {
        searchDebounce?.cancel()
        guard isSearching else {
            searchResults = []
            return
        }
        let task = DispatchWorkItem { runSearch() }
        searchDebounce = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }

    private func runSearch() {
        IngredientService.searchIngredients(query: searchText, kind: nil) { searchResults = $0 }
    }
}

// MARK: - Drill-in: a generic's brands (generic listed first)

private struct BrandListView: View {
    let generic: Ingredient
    let onSelect: (Ingredient) -> Void

    @State private var brands: [Ingredient] = []
    @State private var hasLoaded = false
    @State private var showCreate = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Generic first: "I have generic <name>".
                IngredientPickRow(ingredient: generic, subtitle: "Generic \(generic.name)") {
                    onSelect(generic)
                }

                ForEach(brands) { brand in
                    IngredientPickRow(ingredient: brand) { onSelect(brand) }
                }

                Button { showCreate = true } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add your own \(generic.name)")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.orange)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .barBackground()
        .navigationTitle(generic.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showCreate) {
            CreateBarIngredientForm(kind: generic.kind, onCreated: onSelect)
                .presentationDetents([.medium])
        }
        .onAppear {
            if !hasLoaded { load() }
        }
    }

    private func load() {
        IngredientService.fetchBrands(parentId: generic.id) { fetched in
            brands = fetched
            hasLoaded = true
        }
    }
}

// MARK: - Shared pieces

private struct CategoryTile: View {
    let name: String
    let kind: String
    let imageUrl: String?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.10))
                if let imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit().padding(10)
                    } placeholder: {
                        tileIcon
                    }
                } else {
                    tileIcon
                }
            }
            .frame(height: 84)
            Text(name)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.white.opacity(0.12))
        .cornerRadius(16)
    }

    private var tileIcon: some View {
        Image(systemName: IngredientKind.icon(for: kind))
            .font(.system(size: 34))
            .foregroundColor(.orange.opacity(0.9))
    }
}

private struct IngredientPickRow: View {
    let ingredient: Ingredient
    var subtitle: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: IngredientKind.icon(for: ingredient.kind))
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .frame(width: 28)
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
                    Text(subtitle ?? IngredientKind.label(for: ingredient.kind))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.orange)
            }
            .frostedCard()
        }
        .buttonStyle(.plain)
    }
}

private struct CreateBarIngredientForm: View {
    let kind: String
    let onCreated: (Ingredient) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var abvText = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    frostedTextField("Name", text: $name)
                    frostedTextField("ABV %", text: $abvText)
                        .keyboardType(.decimalPad)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button(action: create) {
                        if isCreating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Add to \(IngredientKind.label(for: kind))")
                        }
                    }
                    .buttonStyle(GradientCapsuleButtonStyle())
                    .disabled(isCreating || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .barBackground()
            .navigationTitle("New \(IngredientKind.label(for: kind))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(.white)
                }
            }
        }
    }

    private func create() {
        let abv = Double(abvText.replacingOccurrences(of: ",", with: "."))
        isCreating = true
        IngredientService.createIngredient(
            name: name.trimmingCharacters(in: .whitespaces),
            kind: kind,
            abv: abv
        ) { result in
            isCreating = false
            switch result {
            case .success(let ingredient):
                onCreated(ingredient) // dismisses the whole add flow
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
