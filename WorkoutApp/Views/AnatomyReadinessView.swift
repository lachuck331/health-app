import SwiftUI
import SwiftData

struct AnatomyReadinessView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var profiles: [MuscleProfile]
    @Query private var checkIns: [RecoveryCheckIn]
    @State private var selectedMuscle: Muscle?

    private var states: [MuscleState] {
        TrainingSnapshotBuilder.muscleStates(
            workouts: workouts,
            profiles: profiles,
            checkIns: checkIns
        )
    }

    private var readiness: [Muscle: Double] {
        Dictionary(uniqueKeysWithValues: states.map { ($0.muscle, $0.readiness) })
    }

    private var readyCount: Int {
        states.filter { $0.readiness >= 65 }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("RECOVERY MAP")
                        .font(.caption2.weight(.bold))
                        .tracking(1.7)
                        .foregroundStyle(.secondary)
                    Text("Know what to train next")
                        .font(.title2.bold())
                    Text("Your last seven days of training, translated into muscle readiness.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    statusPill(
                        icon: "checkmark",
                        value: readyCount,
                        text: "Ready",
                        color: .green
                    )
                    statusPill(
                        icon: "clock.fill",
                        value: max(0, states.count - readyCount),
                        text: "Recovering",
                        color: .red
                    )
                }

                AnatomySceneView(readiness: readiness) { muscle in
                    selectedMuscle = muscle
                }
                .accessibilityLabel("Interactive muscle readiness body map")
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }

                Label("Tap any colored muscle for volume and exercises", systemImage: "hand.tap")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedMuscle) { muscle in
            NavigationStack {
                if let state = states.first(where: { $0.muscle == muscle }) {
                    MuscleReadinessDetailView(muscle: muscle, state: state)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func statusPill(icon: String, value: Int, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.headline.monospacedDigit())
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MuscleReadinessDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var selections: [MuscleExerciseSelection]

    let muscle: Muscle
    let state: MuscleState

    private var muscleSelections: [MuscleExerciseSelection] {
        selections.filter { $0.muscle == muscle }.sorted { $0.order < $1.order }
    }

    private var selectedNames: Set<String> {
        Set(muscleSelections.map(\.exerciseName))
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 18) {
                    readinessRing
                    VStack(alignment: .leading, spacing: 7) {
                        Text("\(state.effectiveSetsLast7Days.formattedSets) of \(state.targetEffectiveSetsLast7Days.formattedSets) effective sets")
                            .font(.headline)
                        ProgressView(
                            value: min(state.effectiveSetsLast7Days, state.targetEffectiveSetsLast7Days),
                            total: max(1, state.targetEffectiveSetsLast7Days)
                        )
                        Text("Rolling seven-day volume")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("Your exercises") {
                if muscleSelections.isEmpty {
                    ContentUnavailableView(
                        "No primary exercise",
                        systemImage: "dumbbell",
                        description: Text("Choose an approved exercise below.")
                    )
                }

                ForEach(muscleSelections) { selection in
                    selectionRow(selection)
                }
            }

            Section("Approved for \(muscle.rawValue)") {
                ForEach(involvingExercises) { exercise in
                    NavigationLink {
                        ExerciseLoggerView(exercise: exercise)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(exercise.name)
                            Text(exercise.primaryMuscle == muscle ? "Primary muscle" : "Secondary contribution")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(muscle.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private var readinessRing: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 8)
            Circle()
                .trim(from: 0, to: state.readiness / 100)
                .stroke(state.readiness >= 65 ? Color.green : Color.red, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(state.readiness.roundedPercent)%")
                .font(.headline.monospacedDigit())
        }
        .frame(width: 72, height: 72)
    }

    @ViewBuilder
    private func selectionRow(_ selection: MuscleExerciseSelection) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(selection.exerciseName)
                    .font(.body.weight(.semibold))
                if let exercise = ExerciseSeed.approved.first(where: { $0.name == selection.exerciseName }) {
                    Text(exercise.primaryMuscle == muscle ? "Primary" : "Secondary")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu("Replace") {
                let alternatives = involvingExercises.filter { !selectedNames.contains($0.name) }
                if alternatives.isEmpty {
                    Text("No other approved options")
                } else {
                    ForEach(alternatives) { replacement in
                        Button(replacement.name) {
                            selection.exerciseName = replacement.name
                            try? modelContext.save()
                        }
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private var involvingExercises: [ExerciseSeed] {
        ExerciseSeed.approved
            .filter { $0.primaryMuscle == muscle || $0.secondaryMuscle == muscle }
            .sorted {
                if ($0.primaryMuscle == muscle) != ($1.primaryMuscle == muscle) {
                    return $0.primaryMuscle == muscle
                }
                return $0.name < $1.name
            }
    }
}
