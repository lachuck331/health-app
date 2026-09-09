import SwiftUI
import SwiftData

private enum ExerciseShelf: String, CaseIterable, Identifiable {
    case active = "Active"
    case archive = "Archive"

    var id: String { rawValue }
}

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ExerciseDefinition.name) private var definitions: [ExerciseDefinition]
    @State private var shelf = ExerciseShelf.active
    @State private var showsAddExercise = false

    private var visibleDefinitions: [ExerciseDefinition] {
        definitions.filter { definition in
            shelf == .active ? !definition.isArchived : definition.isArchived
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            controls

            if visibleDefinitions.isEmpty {
                ContentUnavailableView(
                    shelf == .active ? "No Active Exercises" : "Archive Is Empty",
                    systemImage: shelf == .active ? "figure.strengthtraining.traditional" : "archivebox",
                    description: Text(shelf == .active ? "Tap + to add an exercise." : "Swipe an active exercise to archive it.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                exerciseList
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsAddExercise = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add exercise")
            }
        }
        .sheet(isPresented: $showsAddExercise) {
            AddExerciseView()
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Exercise status", selection: $shelf) {
                ForEach(ExerciseShelf.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 16) {
                venueKey("Gym", color: .indigo)
                venueKey("Park", color: .green)
                Spacer()
                Text("\(visibleDefinitions.count) \(visibleDefinitions.count == 1 ? "exercise" : "exercises")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Label(
                shelf == .active ? "Swipe left to archive" : "Swipe left to restore",
                systemImage: "hand.draw"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var exerciseList: some View {
        List {
            ForEach(Muscle.allCases) { muscle in
                let exercises = visibleDefinitions.filter { $0.primaryMuscle == muscle }
                if !exercises.isEmpty {
                    Section(muscle.rawValue) {
                        ForEach(exercises) { definition in
                            libraryRow(for: definition)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func libraryRow(for definition: ExerciseDefinition) -> some View {
        if shelf == .active {
            NavigationLink {
                ExerciseLoggerView(exercise: definition.seed, venue: preferredVenue(for: definition))
            } label: {
                ExerciseLibraryRow(definition: definition)
            }
            .swipeActions(edge: .trailing) {
                Button {
                    move(definition, toArchive: true)
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                .tint(.orange)
            }
        } else {
            ExerciseLibraryRow(definition: definition)
                .swipeActions(edge: .trailing) {
                    Button {
                        move(definition, toArchive: false)
                    } label: {
                        Label("Restore", systemImage: "arrow.uturn.backward")
                    }
                    .tint(.green)
                }
        }
    }

    private func venueKey(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Capsule()
                .fill(color)
                .frame(width: 4, height: 13)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func preferredVenue(for definition: ExerciseDefinition) -> TrainingVenue {
        definition.isGymAvailable ? .gym : .park
    }

    private func move(_ definition: ExerciseDefinition, toArchive: Bool) {
        withAnimation {
            definition.isArchived = toArchive
            try? modelContext.save()
        }
    }
}

private struct ExerciseLibraryRow: View {
    let definition: ExerciseDefinition

    var body: some View {
        HStack(spacing: 12) {
            venueBar

            VStack(alignment: .leading, spacing: 4) {
                Text(definition.name)
                    .font(.body.weight(.semibold))

                HStack(spacing: 5) {
                    Text(definition.targetSetsPerWeek.formattedSets + " suggested sets")
                    if let secondary = definition.secondaryMuscle {
                        Text("·")
                        Text("+ \(secondary.rawValue)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(venueLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(definition.name), \(definition.primaryMuscle.rawValue), \(venueLabel)")
    }

    private var venueBar: some View {
        VStack(spacing: 2) {
            if definition.isGymAvailable {
                Color.indigo
            }
            if definition.isParkAvailable {
                Color.green
            }
        }
        .frame(width: 4, height: 38)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }

    private var venueLabel: String {
        switch (definition.isGymAvailable, definition.isParkAvailable) {
        case (true, true): "GYM + PARK"
        case (true, false): "GYM"
        case (false, true): "PARK"
        case (false, false): "UNASSIGNED"
        }
    }
}

private struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var definitions: [ExerciseDefinition]

    @State private var name = ""
    @State private var primaryMuscle = Muscle.chest
    @State private var secondaryMuscle: Muscle?
    @State private var weeklySets = 3
    @State private var isGymAvailable = true
    @State private var isParkAvailable = false
    @State private var saveError: String?
    @FocusState private var nameIsFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var duplicateExists: Bool {
        definitions.contains { $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !duplicateExists && (isGymAvailable || isParkAvailable)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameIsFocused)

                    if duplicateExists {
                        Label("An exercise with this name already exists.", systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }

                    Picker("Primary muscle", selection: $primaryMuscle) {
                        ForEach(Muscle.allCases) { muscle in
                            Text(muscle.rawValue).tag(muscle)
                        }
                    }

                    Picker("Secondary muscle", selection: $secondaryMuscle) {
                        Text("None").tag(nil as Muscle?)
                        ForEach(Muscle.allCases) { muscle in
                            Text(muscle.rawValue).tag(Optional(muscle))
                        }
                    }

                    Stepper("Suggested sets: \(weeklySets)", value: $weeklySets, in: 1...20)
                }

                Section("Available at") {
                    Toggle("Gym", isOn: $isGymAvailable)
                        .disabled(isGymAvailable && !isParkAvailable)
                    Toggle("Park", isOn: $isParkAvailable)
                        .disabled(isParkAvailable && !isGymAvailable)
                    Text("Choose both when the movement works in either setting.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .disabled(!canSave)
                }
            }
            .task { nameIsFocused = true }
            .alert("Couldn’t add exercise", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveError ?? "Unknown error")
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let definition = ExerciseDefinition(
            name: trimmedName,
            targetSetsPerWeek: Double(weeklySets),
            primaryMuscle: primaryMuscle,
            secondaryMuscle: secondaryMuscle,
            isGymAvailable: isGymAvailable,
            isParkAvailable: isParkAvailable
        )
        modelContext.insert(definition)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
