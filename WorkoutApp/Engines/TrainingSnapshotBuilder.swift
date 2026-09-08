import Foundation

enum TrainingSnapshotBuilder {
    static func muscleStates(
        workouts: [Workout],
        profiles: [MuscleProfile],
        checkIns: [RecoveryCheckIn],
        now: Date = .now
    ) -> [MuscleState] {
        let targets = ExerciseSeed.weeklyTargets()
        let observations = checkIns.map {
            RecoveryObservation(muscle: $0.muscle, timestamp: $0.timestamp, score: $0.recoveryScore)
        }
        var exposures: [MuscleExposure] = []

        for workout in workouts {
            guard let completedAt = workout.finishedAt else { continue }
            for loggedExercise in workout.exercises {
                guard let exercise = loggedExercise.exercise else { continue }
                let setCount = loggedExercise.sets.count
                guard setCount > 0 else { continue }
                exposures.append(
                    MuscleExposure(
                        muscle: exercise.primaryMuscle,
                        completedAt: completedAt,
                        effectiveSets: Double(setCount) * exercise.primaryWeight
                    )
                )
                if let secondary = exercise.secondaryMuscle,
                   let secondaryWeight = exercise.secondaryWeight {
                    exposures.append(
                        MuscleExposure(
                            muscle: secondary,
                            completedAt: completedAt,
                            effectiveSets: Double(setCount) * secondaryWeight
                        )
                    )
                }
            }
        }

        let calculator = FatigueCalculator()
        return Muscle.allCases.map { muscle in
            let learnedHours = profiles.first(where: { $0.muscle == muscle })?.learnedRecoveryHours ?? 48
            return calculator.state(
                for: muscle,
                exposures: exposures,
                checkIns: observations,
                learnedRecoveryHours: learnedHours,
                targetEffectiveSets: targets[muscle, default: 0],
                at: now
            )
        }
    }
}
