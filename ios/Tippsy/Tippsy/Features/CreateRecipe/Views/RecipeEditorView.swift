//
//  RecipeEditorView.swift
//  Tippsy
//
//  The recipe editor behind the log/create flow. In .log mode it opens
//  prefilled from an existing recipe: submitting untouched just logs it;
//  any edit publishes a modified community variant (same title, linked to
//  the original) and attaches the log to that. In .scratch mode it is a
//  blank create form with an optional "log it now" section.
//

import PhotosUI
import SwiftUI

struct RecipeEditorView: View {
    enum Mode: Hashable {
        case scratch
        case log(RecipeDetail)
    }

    let mode: Mode
    @ObservedObject var viewModel: UserViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var draft: RecipeDraft
    private let snapshot: RecipeDraft? // log mode: the untouched prefill

    @State private var glasses: [GlassType] = []
    @State private var garnishEnabled: Bool
    @State private var showGarnishOffConfirm = false

    @State private var photoItem: PhotosPickerItem?
    @State private var photoImage: UIImage?

    @State private var showIngredientPicker = false
    @State private var showGarnishPicker = false
    @State private var editingLineID: UUID?
    @State private var draggingLineID: UUID?

    @State private var logExpanded: Bool
    @State private var rating: Int?
    @State private var comment = ""
    @State private var impairment = 1

    @State private var isSubmitting = false
    @State private var showAlert = false
    @State private var alertTitle = "Notice"
    @State private var alertMessage = ""
    @State private var dismissOnAlertOK = false

    init(mode: Mode, viewModel: UserViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        switch mode {
        case .scratch:
            snapshot = nil
            _draft = State(initialValue: RecipeDraft())
            _garnishEnabled = State(initialValue: false)
            _logExpanded = State(initialValue: false)
        case .log(let detail):
            let prefill = RecipeDraft(from: detail)
            snapshot = prefill
            _draft = State(initialValue: prefill)
            _garnishEnabled = State(initialValue: !prefill.garnishLines.isEmpty)
            _logExpanded = State(initialValue: true)
        }
    }

    private var measurePref: String {
        viewModel.user?.measurePref ?? "metric"
    }

    /// Any edit to the prefill makes this a new community variant.
    private var isDirty: Bool {
        guard let snapshot else { return false }
        return draft != snapshot
    }

    private var isValid: Bool {
        let hasName: Bool
        if case .scratch = mode {
            hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            hasName = true
        }
        return hasName
            && !draft.glassSlug.isEmpty
            && !draft.regularLines.isEmpty
            && draft.lines.count <= 30
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if case .log = mode, isDirty {
                    modifiedBanner
                }

                basicsSection
                photoSection
                ingredientsSection
                if garnishEnabled || !draft.garnishLines.isEmpty {
                    garnishSection
                }
                instructionsSection
                logSection

                Button(action: submit) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(submitTitle)
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
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showIngredientPicker) {
            IngredientPickerSheet { ingredient in
                addLine(ingredient: ingredient, isGarnish: false)
            }
        }
        .sheet(isPresented: $showGarnishPicker) {
            IngredientPickerSheet(lockedKind: "garnish") { ingredient in
                addLine(ingredient: ingredient, isGarnish: true)
            }
        }
        .sheet(item: editingLineBinding) { line in
            RecipeLineEditorSheet(line: line, measurePref: measurePref) { updated in
                if let idx = draft.lines.firstIndex(where: { $0.id == updated.id }) {
                    draft.lines[idx] = updated
                }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Remove garnishes?", isPresented: $showGarnishOffConfirm) {
            Button("Remove", role: .destructive) {
                draft.lines.removeAll(where: \.isGarnish)
                garnishEnabled = false
            }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Turning this off removes the garnishes from your recipe.")
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                if dismissOnAlertOK { dismiss() }
            }
        } message: {
            Text(alertMessage)
        }
        .onAppear(perform: loadGlasses)
    }

    // MARK: - Derived labels

    private var navigationTitle: String {
        switch mode {
        case .scratch: return "New Recipe"
        case .log(let detail): return detail.name
        }
    }

    private var submitTitle: String {
        switch mode {
        case .scratch: return "Create Recipe"
        case .log: return isDirty ? "Publish My Version & Log" : "Log It"
        }
    }

    private var modifiedBanner: some View {
        Label("Modified — this will publish your version, linked to the original", systemImage: "arrow.triangle.branch")
            .font(.caption.weight(.semibold))
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frostedCard()
    }

    // MARK: - Sections

    private var basicsSection: some View {
        VStack(spacing: 12) {
            if case .scratch = mode {
                frostedTextField("Name your drink", text: $name)
            }

            frostedTextField("Describe it", text: $draft.description)

            VStack(alignment: .leading, spacing: 8) {
                Text("Method")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))

                HStack(spacing: 4) {
                    ForEach(RecipeMethod.all, id: \.self) { m in
                        Button {
                            draft.method = m
                        } label: {
                            Text(m.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background {
                                    if draft.method == m {
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

            glassRow
            sweetnessRow
        }
    }

    private var glassRow: some View {
        HStack {
            Text("Glass")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Menu {
                ForEach(glasses) { glass in
                    Button(glass.name) { draft.glassSlug = glass.slug }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(currentGlassName)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
            }
        }
        .frostedCard()
    }

    private var currentGlassName: String {
        glasses.first { $0.slug == draft.glassSlug }?.name
            ?? (draft.glassSlug.isEmpty ? "Choose" : draft.glassSlug.capitalized)
    }

    private var sweetnessRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: sweetnessBinding) {
                Text(draft.sweetness.map { "Sweetness: \($0)/10" } ?? "Set sweetness")
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .tint(.orange)

            if let sweetness = draft.sweetness {
                Slider(
                    value: Binding(
                        get: { Double(sweetness) },
                        set: { draft.sweetness = Int($0) }
                    ),
                    in: 0...10,
                    step: 1
                )
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

    private var sweetnessBinding: Binding<Bool> {
        Binding(
            get: { draft.sweetness != nil },
            set: { draft.sweetness = $0 ? 5 : nil }
        )
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
            HStack {
                Text("Ingredients")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if !garnishEnabled {
                    Toggle("Garnish", isOn: garnishToggleBinding)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .tint(.orange)
                        .fixedSize()
                }
            }

            if draft.regularLines.isEmpty {
                Text("Drag lines to reorder them once added")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            ForEach(draft.regularLines) { line in
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

    private var garnishSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Garnish")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Toggle("", isOn: garnishToggleBinding)
                    .labelsHidden()
                    .tint(.orange)
            }

            ForEach(draft.garnishLines) { line in
                lineRow(line)
            }

            Button {
                showGarnishPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add garnish")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
            }
            .padding(.top, 2)
        }
        .frostedCard()
    }

    private var garnishToggleBinding: Binding<Bool> {
        Binding(
            get: { garnishEnabled },
            set: { newValue in
                if !newValue && !draft.garnishLines.isEmpty {
                    showGarnishOffConfirm = true
                } else {
                    garnishEnabled = newValue
                }
            }
        )
    }

    private func lineRow(_ line: DraftLine) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))

            Text(amountLabel(line))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.orange)
                .frame(width: 70, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(line.ingredientName)
                    .font(.subheadline)
                    .foregroundColor(.white)
                if !line.note.isEmpty {
                    Text(line.note)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            Button {
                draft.lines.removeAll { $0.id == line.id }
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.white.opacity(draggingLineID == line.id ? 0.25 : 0.1))
        .cornerRadius(10)
        .contentShape(Rectangle())
        .onTapGesture {
            editingLineID = line.id
        }
        .onDrag {
            draggingLineID = line.id
            return NSItemProvider(object: line.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: LineReorderDropDelegate(
            item: line,
            lines: $draft.lines,
            draggingID: $draggingLineID
        ))
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Instructions")
                .font(.headline)
                .foregroundColor(.white)

            TextField(
                "How to make it",
                text: $draft.instructions,
                prompt: Text("How to make it").foregroundColor(.white.opacity(0.6)),
                axis: .vertical
            )
            .lineLimit(4...10)
            .foregroundColor(.white)
            .tint(.white)
        }
        .frostedCard()
    }

    @ViewBuilder
    private var logSection: some View {
        switch mode {
        case .log:
            VStack(alignment: .leading, spacing: 10) {
                Text("Your log")
                    .font(.headline)
                    .foregroundColor(.white)
                LogSectionView(rating: $rating, comment: $comment, impairment: $impairment)
            }
        case .scratch:
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $logExpanded) {
                    Text("Log it right away")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .tint(.orange)

                if logExpanded {
                    LogSectionView(rating: $rating, comment: $comment, impairment: $impairment)
                }
            }
            .frostedCard()
        }
    }

    // MARK: - Helpers

    private var editingLineBinding: Binding<DraftLine?> {
        Binding(
            get: { draft.lines.first { $0.id == editingLineID } },
            set: { if $0 == nil { editingLineID = nil } }
        )
    }

    private func amountLabel(_ line: DraftLine) -> String {
        guard let amount = line.amount else {
            return line.unitCode ?? "—"
        }
        let text = AmountWheelPicker.label(for: amount)
        if let unitCode = line.unitCode {
            return "\(text) \(unitCode)"
        }
        return text
    }

    private func addLine(ingredient: Ingredient, isGarnish: Bool) {
        IngredientService.fetchUnits { units in
            let line = DraftLine(ingredient: ingredient, isGarnish: isGarnish, measurePref: measurePref, units: units)
            draft.lines.append(line)
            if !isGarnish {
                editingLineID = line.id
            }
        }
    }

    private func loadGlasses() {
        GlassService.fetchGlasses { fetched in
            glasses = fetched
            if draft.glassSlug.isEmpty {
                draft.glassSlug = fetched.first { $0.slug == "rocks" }?.slug ?? fetched.first?.slug ?? ""
            }
        }
    }

    // MARK: - Submit

    private func submit() {
        isSubmitting = true
        switch mode {
        case .log(let detail) where !isDirty:
            postLog(recipeId: detail.id, recipeName: detail.name, publishedVariant: false)
        case .log(let detail):
            createRecipe(name: detail.name, parentRecipeId: detail.id) { variant in
                postLog(recipeId: variant.id, recipeName: variant.name, publishedVariant: true)
            }
        case .scratch:
            createRecipe(name: name, parentRecipeId: nil) { recipe in
                if logExpanded {
                    postLog(recipeId: recipe.id, recipeName: recipe.name, publishedVariant: true)
                } else {
                    finish(title: "Recipe Created", message: "\"\(recipe.name)\" is now live in the community.")
                }
            }
        }
    }

    private func createRecipe(name: String, parentRecipeId: String?, onSuccess: @escaping (RecipeDetail) -> Void) {
        RecipeService.createRecipe(payload: draft.payload(name: name, parentRecipeId: parentRecipeId)) { result in
            switch result {
            case .success(let recipe):
                onSuccess(recipe)
            case .failure(let error):
                fail(message: error.localizedDescription)
            }
        }
    }

    private func postLog(recipeId: String, recipeName: String, publishedVariant: Bool) {
        RecipeService.postReview(
            recipeId: recipeId,
            rating: rating,
            comment: comment.trimmingCharacters(in: .whitespaces).isEmpty ? nil : comment,
            impairment: impairment,
            photo: nil
        ) { result in
            switch result {
            case .success:
                if publishedVariant {
                    finish(title: "Published & Logged", message: "Your version of \(recipeName) is live in the community, and your log is attached.")
                } else {
                    finish(title: "Logged", message: "\(recipeName) is in your log.")
                }
            case .failure:
                if publishedVariant {
                    // The recipe row exists; only the two-step log failed.
                    finish(title: "Published", message: "Your version of \(recipeName) was published, but the log failed — you can log it again from the recipe page.")
                } else {
                    fail(message: "Could not save your log. Please try again.")
                }
            }
        }
    }

    private func finish(title: String, message: String) {
        isSubmitting = false
        alertTitle = title
        alertMessage = message
        dismissOnAlertOK = true
        showAlert = true
    }

    private func fail(message: String) {
        isSubmitting = false
        alertTitle = "Notice"
        alertMessage = message
        dismissOnAlertOK = false
        showAlert = true
    }
}

// MARK: - Drag-to-reorder

// Reorders draft lines as a drag passes over other rows. Drops only land
// within the same section: regular lines and garnish reorder independently.
private struct LineReorderDropDelegate: DropDelegate {
    let item: DraftLine
    @Binding var lines: [DraftLine]
    @Binding var draggingID: UUID?

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != item.id,
              let from = lines.firstIndex(where: { $0.id == draggingID }),
              let to = lines.firstIndex(where: { $0.id == item.id }),
              lines[from].isGarnish == lines[to].isGarnish
        else { return }
        withAnimation {
            lines.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        return true
    }
}
