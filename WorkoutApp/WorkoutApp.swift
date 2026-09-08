import SwiftUI
import SwiftData

@main
struct WorkoutApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            MuscleProfile.self,
            ExerciseDefinition.self,
            Workout.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            RecoveryCheckIn.self,
            MuscleExerciseSelection.self
        ])
    }
}
