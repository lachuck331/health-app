import SwiftUI
import SwiftData

struct AnatomyReadinessView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var profiles: [MuscleProfile]
    @Query private var checkIns: [RecoveryCheckIn]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var focusedMuscle: Muscle?
    @State private var detailMuscle: Muscle?
    @State private var pendingDetailTask: Task<Void, Never>?

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
            VStack(alignment: .leading, spacing: 14) {
                if focusedMuscle == nil {
                    overviewHeader
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                AnatomySceneView(readiness: readiness, focusedMuscle: focusedMuscle) { muscle in
                    focus(on: muscle)
                }
                .id("anatomy-map")
                .accessibilityLabel("Interactive muscle readiness body map")
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.quaternary, lineWidth: 1)
                }

                readinessLegend

                if let muscle = detailMuscle,
                   let state = states.first(where: { $0.muscle == muscle }) {
                    MuscleReadinessDetailView(
                        muscle: muscle,
                        state: state,
                        onClose: clearFocus
                    )
                    .id(muscle)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                } else if focusedMuscle == nil {
                    Label("Tap any colored muscle for volume and exercises", systemImage: "hand.tap")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
            .animation(reduceMotion ? nil : .snappy(duration: 0.38, extraBounce: 0.04), value: focusedMuscle)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(focusedMuscle?.rawValue ?? "Body")
        .navigationBarTitleDisplayMode(.inline)
#if DEBUG
        .task {
            guard focusedMuscle == nil,
                  let rawValue = ProcessInfo.processInfo.environment["QA_FOCUSED_MUSCLE"],
                  let muscle = Muscle(rawValue: rawValue)
            else { return }
            focus(on: muscle)
        }
#endif
    }

    private var overviewHeader: some View {
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
                statusPill(icon: "checkmark", value: readyCount, text: "Ready", color: .green)
                statusPill(
                    icon: "clock.fill",
                    value: max(0, states.count - readyCount),
                    text: "Recovering",
                    color: .red
                )
            }
        }
    }

    private func focus(on muscle: Muscle) {
        pendingDetailTask?.cancel()

        guard !reduceMotion else {
            focusedMuscle = muscle
            detailMuscle = muscle
            return
        }

        withAnimation(.snappy(duration: 0.34, extraBounce: 0.04)) {
            focusedMuscle = muscle
            if detailMuscle != muscle {
                detailMuscle = nil
            }
        }

        pendingDetailTask = Task {
            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled, focusedMuscle == muscle else { return }
            withAnimation(.snappy(duration: 0.34, extraBounce: 0.03)) {
                detailMuscle = muscle
            }
        }
    }

    private func clearFocus() {
        pendingDetailTask?.cancel()
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.34, extraBounce: 0.03)) {
            detailMuscle = nil
            focusedMuscle = nil
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
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var readinessLegend: some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(ReadinessColorScale.gradient)
                .frame(height: 8)

            HStack {
                Text("0 · Recovering")
                Spacer()
                Text("Readiness score")
                Spacer()
                Text("100 · Ready")
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Readiness color scale, from zero recovering to one hundred ready")
    }
}

private struct MuscleReadinessDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var selections: [MuscleExerciseSelection]
    @State private var showsApprovedExercises = false

    let muscle: Muscle
    let state: MuscleState
    let onClose: () -> Void

    private var muscleSelections: [MuscleExerciseSelection] {
        selections.filter { $0.muscle == muscle }.sorted { $0.order < $1.order }
    }

    private var selectedNames: Set<String> {
        Set(muscleSelections.map(\.exerciseName))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                readinessRing

                VStack(alignment: .leading, spacing: 5) {
                    Text(muscle.rawValue)
                        .font(.title3.bold())
                    Text("\(state.effectiveSetsLast7Days.formattedSets) of \(state.targetEffectiveSetsLast7Days.formattedSets) effective sets")
                        .font(.subheadline.weight(.semibold))
                    Text("Rolling seven-day volume")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 30, height: 30)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close muscle details")
            }

            ProgressView(
                value: min(state.effectiveSetsLast7Days, state.targetEffectiveSetsLast7Days),
                total: max(1, state.targetEffectiveSetsLast7Days)
            )
            .tint(ReadinessColorScale.color(for: state.readiness))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("YOUR EXERCISES")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)

                if muscleSelections.isEmpty {
                    Label("Choose an approved exercise below", systemImage: "dumbbell")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(muscleSelections.enumerated()), id: \.element.id) { index, selection in
                        selectionRow(selection)
                        if index < muscleSelections.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            DisclosureGroup(isExpanded: $showsApprovedExercises) {
                VStack(spacing: 0) {
                    ForEach(involvingExercises) { exercise in
                        NavigationLink {
                            ExerciseLoggerView(exercise: exercise)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    Text(exercise.primaryMuscle == muscle ? "Primary muscle" : "Secondary contribution")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 10)
                        }
                        if exercise.id != involvingExercises.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.top, 6)
            } label: {
                Text("All exercises for \(muscle.rawValue)")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(18)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var readinessRing: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 7)
            Circle()
                .trim(from: 0, to: state.readiness / 100)
                .stroke(
                    ReadinessColorScale.color(for: state.readiness),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(state.readiness.roundedPercent)%")
                .font(.subheadline.bold().monospacedDigit())
        }
        .frame(width: 64, height: 64)
    }

    private func selectionRow(_ selection: MuscleExerciseSelection) -> some View {
        HStack(spacing: 12) {
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

            Menu {
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
            } label: {
                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
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
