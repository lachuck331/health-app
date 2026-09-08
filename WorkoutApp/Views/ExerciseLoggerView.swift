import SwiftUI
import SwiftData

struct ExerciseLoggerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var definitions: [ExerciseDefinition]
    @Query private var history: [WorkoutExercise]

    let exercise: ExerciseSeed
    @State private var sets: [EditableSet]
    @State private var loadedPreviousValues = false
    @State private var saveError: String?

    init(exercise: ExerciseSeed) {
        self.exercise = exercise
        let count = max(1, Int(exercise.targetSetsPerWeek.rounded()))
        _sets = State(initialValue: (1...count).map {
            EditableSet(setNumber: $0, weight: 0, reps: 8)
        })
    }

    private var completedCount: Int { sets.count(where: \.isComplete) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(spacing: 10) {
                    ForEach($sets) { $set in
                        SetEntryRow(set: $set)
                    }
                }

                Button {
                    addSet()
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    saveExercise()
                } label: {
                    Text(completedCount == 0 ? "Complete sets to save" : "Save \(completedCount) completed \(completedCount == 1 ? "set" : "sets")")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(completedCount == 0)
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { loadPreviousValues() }
        .alert("Couldn’t save workout", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError ?? "Unknown error")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(exercise.primaryMuscle.rawValue, systemImage: "figure.strengthtraining.traditional")
                Spacer()
                Text("\(completedCount) / \(sets.count) complete")
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.semibold))

            Text("Tap a number for exact entry. Use − / + for quick changes, then check off each completed set.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func loadPreviousValues() {
        guard !loadedPreviousValues else { return }
        loadedPreviousValues = true
        guard let previous = history
            .filter({ $0.exercise?.name == exercise.name && $0.workout?.finishedAt != nil })
            .max(by: { ($0.workout?.finishedAt ?? .distantPast) < ($1.workout?.finishedAt ?? .distantPast) })
        else { return }

        let previousSets = previous.sets.sorted { $0.setNumber < $1.setNumber }
        guard !previousSets.isEmpty else { return }
        sets = previousSets.enumerated().map { index, previousSet in
            EditableSet(
                setNumber: index + 1,
                weight: previousSet.weight,
                reps: previousSet.reps,
                previousWeight: previousSet.weight,
                previousReps: previousSet.reps
            )
        }
    }

    private func addSet() {
        let source = sets.last
        sets.append(
            EditableSet(
                setNumber: sets.count + 1,
                weight: source?.weight ?? 0,
                reps: source?.reps ?? 8,
                previousWeight: source?.previousWeight,
                previousReps: source?.previousReps
            )
        )
    }

    private func saveExercise() {
        guard let definition = definitions.first(where: { $0.name == exercise.name }) else {
            saveError = "The exercise database is still loading. Go back and try again."
            return
        }
        let completedSets = sets.filter(\.isComplete)
        guard !completedSets.isEmpty else { return }

        let now = Date.now
        let workout = Workout(startedAt: now, finishedAt: now)
        let loggedExercise = WorkoutExercise(exercise: definition, workout: workout, order: 0)
        workout.exercises.append(loggedExercise)
        for (index, entry) in completedSets.enumerated() {
            loggedExercise.sets.append(
                WorkoutSet(
                    setNumber: index + 1,
                    weight: entry.weight,
                    reps: entry.reps,
                    workoutExercise: loggedExercise
                )
            )
        }
        modelContext.insert(workout)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct EditableSet: Identifiable {
    let id = UUID()
    var setNumber: Int
    var weight: Double
    var reps: Int
    var previousWeight: Double?
    var previousReps: Int?
    var isComplete = false
}

private struct SetEntryRow: View {
    @Binding var set: EditableSet

    var body: some View {
        HStack(spacing: 10) {
            Text("\(set.setNumber)")
                .font(.headline.monospacedDigit())
                .frame(width: 30, height: 30)
                .background(.quaternary, in: Circle())

            WeightControl(value: $set.weight, previous: set.previousWeight)
            RepControl(value: $set.reps, previous: set.previousReps)

            Button {
                set.isComplete.toggle()
            } label: {
                Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isComplete ? .green : .secondary)
                    .frame(width: 38, height: 44)
            }
            .accessibilityLabel(set.isComplete ? "Mark set incomplete" : "Complete set")
        }
        .padding(10)
        .background(set.isComplete ? Color.green.opacity(0.1) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .animation(.easeOut(duration: 0.15), value: set.isComplete)
    }
}

private struct WeightControl: View {
    @Binding var value: Double
    let previous: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text("WEIGHT")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                adjustButton("minus", amount: -5)
                TextField("0", value: $value, format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 38)
                adjustButton("plus", amount: 5)
            }
            Text(previous.map { "prev \($0.formattedSets)" } ?? "lb")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func adjustButton(_ systemName: String, amount: Double) -> some View {
        Button {
            value = min(2_000, max(0, value + amount))
        } label: {
            Image(systemName: systemName)
                .font(.caption.bold())
                .frame(width: 24, height: 30)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

private struct RepControl: View {
    @Binding var value: Int
    let previous: Int?

    var body: some View {
        VStack(spacing: 4) {
            Text("REPS")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                adjustButton("minus", amount: -1)
                TextField("0", value: $value, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 24)
                adjustButton("plus", amount: 1)
            }
            Text(previous.map { "prev \($0)" } ?? "reps")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func adjustButton(_ systemName: String, amount: Int) -> some View {
        Button {
            value = min(100, max(0, value + amount))
        } label: {
            Image(systemName: systemName)
                .font(.caption.bold())
                .frame(width: 24, height: 30)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}
