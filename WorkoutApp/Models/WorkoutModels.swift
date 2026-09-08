import Foundation
import SwiftData

@Model
final class Workout {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise]

    init(id: UUID = UUID(), startedAt: Date = .now, finishedAt: Date? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        exercises = []
    }
}

@Model
final class WorkoutExercise {
    var exercise: ExerciseDefinition?
    var workout: Workout?
    var order: Int
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workoutExercise)
    var sets: [WorkoutSet]

    init(exercise: ExerciseDefinition, workout: Workout? = nil, order: Int) {
        self.exercise = exercise
        self.workout = workout
        self.order = order
        sets = []
    }
}

@Model
final class WorkoutSet {
    var workoutExercise: WorkoutExercise?
    var setNumber: Int
    var weight: Double
    var reps: Int

    init(setNumber: Int, weight: Double, reps: Int, workoutExercise: WorkoutExercise? = nil) {
        self.setNumber = setNumber
        self.weight = weight
        self.reps = reps
        self.workoutExercise = workoutExercise
    }
}

@Model
final class RecoveryCheckIn {
    @Attribute(.unique) var id: UUID
    var muscleName: String
    var timestamp: Date
    private var storedRecoveryScore: Int

    var muscle: Muscle { Muscle(rawValue: muscleName)! }
    var recoveryScore: Int {
        get { storedRecoveryScore }
        set { storedRecoveryScore = min(5, max(1, newValue)) }
    }

    init(id: UUID = UUID(), muscle: Muscle, timestamp: Date = .now, recoveryScore: Int) {
        self.id = id
        muscleName = muscle.rawValue
        self.timestamp = timestamp
        storedRecoveryScore = min(5, max(1, recoveryScore))
    }
}
