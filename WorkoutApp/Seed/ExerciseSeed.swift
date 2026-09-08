import Foundation

struct ExerciseSeed: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let targetSetsPerWeek: Double
    let primaryMuscle: Muscle
    let primaryWeight: Double
    let secondaryMuscle: Muscle?
    let secondaryWeight: Double?

    init(_ name: String, _ sets: Double, _ primary: Muscle, secondary: Muscle? = nil, secondaryWeight: Double? = nil) {
        self.name = name
        targetSetsPerWeek = sets
        primaryMuscle = primary
        primaryWeight = 1
        secondaryMuscle = secondary
        self.secondaryWeight = secondaryWeight
    }

    static let approved: [ExerciseSeed] = [
        .init("Hack Squat", 3, .quads, secondary: .glutes, secondaryWeight: 0.5),
        .init("RDL", 3, .hamstrings, secondary: .glutes, secondaryWeight: 0.5),
        .init("Abductors", 1, .glutes),
        .init("Adductors", 1, .adductors),
        .init("Cable Crunch", 3, .core),
        .init("Hollow Body Hold", 6, .core),
        .init("Dips", 3, .chest, secondary: .triceps, secondaryWeight: 0.5),
        .init("Pec Deck", 3, .chest),
        .init("JM Press", 3, .triceps, secondary: .chest, secondaryWeight: 0.5),
        .init("Standing Shoulder Press", 2, .shoulders, secondary: .triceps, secondaryWeight: 0.5),
        .init("Pull Ups", 3, .lats, secondary: .biceps, secondaryWeight: 0.5),
        .init("Chest Supported Row", 3, .upperBack, secondary: .lats, secondaryWeight: 0.5),
        .init("Back Extension", 3, .lowerBack, secondary: .hamstrings, secondaryWeight: 0.5),
        .init("Lateral Raise", 2, .shoulders),
        .init("Calf Raise", 2, .calves),
        .init("Tib Raise", 2, .tibialis),
        .init("Cable Bicep Curl", 3, .biceps),
        .init("Leg Curl", 2, .hamstrings)
    ]

    static func weeklyTargets(from exercises: [ExerciseSeed] = approved) -> [Muscle: Double] {
        var result = Dictionary(uniqueKeysWithValues: Muscle.allCases.map { ($0, 0.0) })
        for exercise in exercises {
            result[exercise.primaryMuscle, default: 0] += exercise.targetSetsPerWeek * exercise.primaryWeight
            if let secondary = exercise.secondaryMuscle, let weight = exercise.secondaryWeight {
                result[secondary, default: 0] += exercise.targetSetsPerWeek * weight
            }
        }
        return result
    }
}
