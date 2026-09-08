import SwiftUI
import SwiftData

struct StartWorkoutView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var profiles: [MuscleProfile]
    @Query private var checkIns: [RecoveryCheckIn]
    @State private var venue = TrainingVenue.gym

    private var venueExercises: [ExerciseSeed] {
        ExerciseSeed.exercises(for: venue)
    }

    private var states: [MuscleState] {
        TrainingSnapshotBuilder.muscleStates(
            workouts: workouts,
            profiles: profiles,
            checkIns: checkIns
        )
    }

    private var allRecommendations: [ExerciseRecommendation] {
        RecommendationEngine().recommendations(exercises: venueExercises, states: states)
    }

    private var recommendations: [ExerciseRecommendation] {
        RecommendationEngine().topThree(exercises: venueExercises, states: states)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                venuePicker

                Text("Best \(venue.rawValue.lowercased()) choices based on muscle readiness, time since training, and weekly volume.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(Array(recommendations.enumerated()), id: \.element.exercise.id) { index, recommendation in
                    NavigationLink {
                        ExerciseLoggerView(exercise: recommendation.exercise, venue: venue)
                    } label: {
                        RecommendationCard(position: index + 1, recommendation: recommendation)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    AllExercisesView(recommendations: allRecommendations, venue: venue)
                } label: {
                    Label("View all \(venue.rawValue.lowercased()) exercises", systemImage: "list.number")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if workouts.isEmpty {
                    Text("No workouts are logged yet, so every muscle starts fully ready. Recommendations will personalize as you add training history.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Start Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var venuePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TRAINING LOCATION")
                .font(.caption2.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Picker("Training location", selection: $venue) {
                ForEach(TrainingVenue.allCases) { option in
                    Label(option.rawValue, systemImage: option.symbolName)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)

            Label(venue.guidance, systemImage: venue.symbolName)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeOut(duration: 0.2), value: venue)
    }
}

struct RecommendationCard: View {
    let position: Int
    let recommendation: ExerciseRecommendation

    private var state: MuscleState { recommendation.primaryState.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("#\(position)")
                    .font(.headline)
                    .foregroundStyle(.tint)
                Text(recommendation.exercise.name)
                    .font(.title2.bold())
                Spacer()
                Text("\(recommendation.score.roundedPercent)%")
                    .font(.headline.monospacedDigit())
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }

            Text(recommendation.exercise.primaryMuscle.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                GridRow {
                    metric("Readiness", "\(state.readiness.roundedPercent)%")
                    metric("Fatigue", "\(state.fatigue.roundedPercent)%")
                }
                GridRow {
                    metric("Last trained", state.hoursSinceLastHit.map { "\(Int($0.rounded()))h ago" } ?? "Never")
                    metric("7-day volume", state.effectiveSetsLast7Days.formattedSets)
                }
                GridRow {
                    metric("Readiness rank", "\(recommendation.primaryState.readinessRank.ordinal) / 14")
                    metric("Time rank", "\(recommendation.primaryState.timeSinceLastHitRank.ordinal) / 14")
                }
            }

            Text("Target: \(state.targetEffectiveSetsLast7Days.formattedSets) effective sets / 7 days")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let explanation = recommendation.explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Double {
    var roundedPercent: Int { Int(rounded()) }

    var formattedSets: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}

extension Int {
    var ordinal: String {
        let tens = self % 100
        if 11...13 ~= tens { return "\(self)th" }
        switch self % 10 {
        case 1: return "\(self)st"
        case 2: return "\(self)nd"
        case 3: return "\(self)rd"
        default: return "\(self)th"
        }
    }
}

private struct AllExercisesView: View {
    let recommendations: [ExerciseRecommendation]
    let venue: TrainingVenue

    var body: some View {
        List(Array(recommendations.enumerated()), id: \.element.exercise.id) { index, recommendation in
            NavigationLink {
                ExerciseLoggerView(exercise: recommendation.exercise, venue: venue)
            } label: {
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recommendation.exercise.name)
                            .font(.body.weight(.semibold))
                        Text("\(recommendation.exercise.primaryMuscle.rawValue) · \(recommendation.primaryState.state.readiness.roundedPercent)% ready")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(recommendation.exercise.venueLabel.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.tint)
                        if let explanation = recommendation.explanation {
                            Text(explanation)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Text("\(recommendation.score.roundedPercent)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(readinessColor(recommendation.primaryState.state.readiness))
                }
                .padding(.vertical, 3)
            }
        }
        .navigationTitle("\(venue.rawValue) Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func readinessColor(_ readiness: Double) -> Color {
        switch readiness {
        case ..<40: .red
        case ..<65: .orange
        case ..<80: .yellow
        default: .green
        }
    }
}
