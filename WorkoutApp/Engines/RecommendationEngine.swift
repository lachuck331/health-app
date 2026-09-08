import Foundation

struct RankedMuscleState: Equatable, Sendable {
    let state: MuscleState
    let readinessRank: Int
    let timeSinceLastHitRank: Int
}

struct ExerciseRecommendation: Equatable, Sendable {
    let exercise: ExerciseSeed
    let score: Double
    let primaryState: RankedMuscleState
    let secondaryPenalty: Double

    var explanation: String? {
        guard let secondary = exercise.secondaryMuscle, secondaryPenalty > 0 else { return nil }
        return "\(exercise.name) ranks lower because \(secondary.rawValue) are below 60% ready."
    }
}

struct RecommendationEngine: Sendable {
    func rankMuscles(_ states: [MuscleState]) -> [Muscle: RankedMuscleState] {
        let readinessOrder = states.sorted {
            $0.readiness == $1.readiness ? $0.muscle.rawValue < $1.muscle.rawValue : $0.readiness > $1.readiness
        }
        let timeOrder = states.sorted {
            let lhs = $0.hoursSinceLastHit ?? .infinity
            let rhs = $1.hoursSinceLastHit ?? .infinity
            return lhs == rhs ? $0.muscle.rawValue < $1.muscle.rawValue : lhs > rhs
        }
        var result: [Muscle: RankedMuscleState] = [:]
        for state in states {
            result[state.muscle] = RankedMuscleState(
                state: state,
                readinessRank: readinessOrder.firstIndex(where: { $0.muscle == state.muscle })! + 1,
                timeSinceLastHitRank: timeOrder.firstIndex(where: { $0.muscle == state.muscle })! + 1
            )
        }
        return result
    }

    func recommendations(exercises: [ExerciseSeed], states: [MuscleState]) -> [ExerciseRecommendation] {
        let ranked = rankMuscles(states)
        return exercises.compactMap { exercise in
            guard let primary = ranked[exercise.primaryMuscle] else { return nil }
            let hours = primary.state.hoursSinceLastHit
            let timeScore = hours.map { min($0 / 72, 1) * 100 } ?? 100
            let target = primary.state.targetEffectiveSetsLast7Days
            let volumeNeed = target > 0
                ? min(1, max(0, (target - primary.state.effectiveSetsLast7Days) / target)) * 100
                : 0
            let secondaryReadiness = exercise.secondaryMuscle.flatMap { ranked[$0]?.state.readiness }
            let penalty = secondaryReadiness.map { max(0, 60 - $0) * 0.25 } ?? 0
            let base = 0.55 * primary.state.readiness + 0.25 * timeScore + 0.20 * volumeNeed
            return ExerciseRecommendation(
                exercise: exercise,
                score: min(100, max(0, base - penalty)),
                primaryState: primary,
                secondaryPenalty: penalty
            )
        }
        .sorted { $0.score == $1.score ? $0.exercise.name < $1.exercise.name : $0.score > $1.score }
    }

    func topThree(exercises: [ExerciseSeed], states: [MuscleState]) -> [ExerciseRecommendation] {
        let all = recommendations(exercises: exercises, states: states)
        var selected: [ExerciseRecommendation] = []
        for recommendation in all where !selected.contains(where: { $0.exercise.primaryMuscle == recommendation.exercise.primaryMuscle }) {
            selected.append(recommendation)
            if selected.count == 3 { return selected }
        }
        for recommendation in all where !selected.contains(recommendation) {
            selected.append(recommendation)
            if selected.count == 3 { break }
        }
        return selected
    }
}
