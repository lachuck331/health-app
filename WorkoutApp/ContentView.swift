import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var exercises: [ExerciseDefinition]
    @Query private var profiles: [MuscleProfile]
    @Query private var selections: [MuscleExerciseSelection]
    @State private var selectedPage = 1

    var body: some View {
        TabView(selection: $selectedPage) {
            NavigationStack {
                AnatomyReadinessView()
            }
            .tag(0)

            NavigationStack {
                VStack(spacing: 20) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Ready to train?")
                        .font(.largeTitle.bold())
                    NavigationLink("Start Workout") {
                        StartWorkoutView()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Label("Swipe right for body readiness", systemImage: "arrow.right")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .tag(1)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .task { seedIfNeeded() }
    }

    private func seedIfNeeded() {
        if profiles.isEmpty {
            Muscle.allCases.forEach { modelContext.insert(MuscleProfile(muscle: $0)) }
        }
        if exercises.isEmpty {
            ExerciseSeed.approved.forEach { modelContext.insert(ExerciseDefinition(seed: $0)) }
        }
        if selections.isEmpty {
            for muscle in Muscle.allCases {
                let defaults = ExerciseSeed.approved.filter { $0.primaryMuscle == muscle }
                for (index, exercise) in defaults.enumerated() {
                    modelContext.insert(
                        MuscleExerciseSelection(
                            muscle: muscle,
                            exerciseName: exercise.name,
                            order: index
                        )
                    )
                }
            }
        }
        try? modelContext.save()
    }
}
