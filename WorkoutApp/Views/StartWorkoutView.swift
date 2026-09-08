import SwiftUI
import SwiftData

struct StartWorkoutView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]
    @Query private var profiles: [MuscleProfile]
    @Query private var checkIns: [RecoveryCheckIn]

    private var states: [MuscleState] {
        TrainingSnapshotBuilder.muscleStates(
            workouts: workouts,
            profiles: profiles,
            checkIns: checkIns
        )
    }

    private var allRecommendations: [ExerciseRecommendation] {
        RecommendationEngine().recommendations(exercises: ExerciseSeed.approved, states: states)
    }

    private var recommendations: [ExerciseRecommendation] {
        RecommendationEngine().topThree(exercises: ExerciseSeed.approved, states: states)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("Best choices based on current muscle readiness, time since training, and weekly volume.")
                    .foregroundStyle(.secondary)

                ForEach(Array(recommendations.enumerated()), id: \.element.exercise.id) { index, recommendation in
                    NavigationLink {
                        ExerciseLoggerView(exercise: recommendation.exercise)
                    } label: {
                        RecommendationCard(position: index + 1, recommendation: recommendation)
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink {
                    AllExercisesView(recommendations: allRecommendations)
                } label: {
                    Label("View all ranked exercises", systemImage: "list.number")
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

    var body: some View {
        List(Array(recommendations.enumerated()), id: \.element.exercise.id) { index, recommendation in
            NavigationLink {
                ExerciseLoggerView(exercise: recommendation.exercise)
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
        .navigationTitle("All Exercises")
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
