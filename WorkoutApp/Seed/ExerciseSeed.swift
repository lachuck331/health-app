import Foundation

enum TrainingVenue: String, Codable, CaseIterable, Identifiable, Sendable {
    case gym = "Gym"
    case park = "Park"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .gym: "dumbbell.fill"
        case .park: "tree.fill"
        }
    }

    var guidance: String {
        switch self {
        case .gym: "Machines, cables, and free weights"
        case .park: "Bars, benches, and bodyweight"
        }
    }
}

struct ExerciseSeed: Identifiable, Equatable, Sendable {
    var id: String { name }
    let name: String
    let targetSetsPerWeek: Double
    let primaryMuscle: Muscle
    let primaryWeight: Double
    let secondaryMuscle: Muscle?
    let secondaryWeight: Double?
    let availableAt: Set<TrainingVenue>

    init(
        _ name: String,
        _ sets: Double,
        _ primary: Muscle,
        secondary: Muscle? = nil,
        secondaryWeight: Double? = nil,
        availableAt: Set<TrainingVenue> = [.gym]
    ) {
        self.name = name
        targetSetsPerWeek = sets
        primaryMuscle = primary
        primaryWeight = 1
        secondaryMuscle = secondary
        self.secondaryWeight = secondaryWeight
        self.availableAt = availableAt
    }

    func supports(_ venue: TrainingVenue) -> Bool {
        availableAt.contains(venue)
    }

    var venueLabel: String {
        TrainingVenue.allCases
            .filter(availableAt.contains)
            .map(\.rawValue)
            .joined(separator: " + ")
    }

    /// The original program remains the source of weekly volume targets. Park
    /// movements below are substitutions, so adding them must not inflate targets.
    static let basePlan: [ExerciseSeed] = [
        .init("Hack Squat", 3, .quads, secondary: .glutes, secondaryWeight: 0.5),
        .init("RDL", 3, .hamstrings, secondary: .glutes, secondaryWeight: 0.5),
        .init("Abductors", 1, .glutes),
        .init("Adductors", 1, .adductors),
        .init("Cable Crunch", 3, .core),
        .init("Hollow Body Hold", 6, .core, availableAt: [.gym, .park]),
        .init("Dips", 3, .chest, secondary: .triceps, secondaryWeight: 0.5, availableAt: [.gym, .park]),
        .init("Pec Deck", 3, .chest),
        .init("JM Press", 3, .triceps, secondary: .chest, secondaryWeight: 0.5),
        .init("Standing Shoulder Press", 2, .shoulders, secondary: .triceps, secondaryWeight: 0.5),
        .init("Pull Ups", 3, .lats, secondary: .biceps, secondaryWeight: 0.5, availableAt: [.gym, .park]),
        .init("Chest Supported Row", 3, .upperBack, secondary: .lats, secondaryWeight: 0.5),
        .init("Back Extension", 3, .lowerBack, secondary: .hamstrings, secondaryWeight: 0.5),
        .init("Lateral Raise", 2, .shoulders),
        .init("Calf Raise", 2, .calves, availableAt: [.gym, .park]),
        .init("Tib Raise", 2, .tibialis),
        .init("Cable Bicep Curl", 3, .biceps),
        .init("Leg Curl", 2, .hamstrings)
    ]

    static let parkAlternatives: [ExerciseSeed] = [
        .init("Bodyweight Squat", 3, .quads, secondary: .glutes, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Bulgarian Split Squat", 3, .quads, secondary: .glutes, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Nordic Hamstring Curl", 3, .hamstrings, secondary: .glutes, secondaryWeight: 0.25, availableAt: [.park]),
        .init("Single-Leg Glute Bridge", 3, .glutes, secondary: .hamstrings, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Side-Lying Leg Raise", 2, .glutes, availableAt: [.park]),
        .init("Copenhagen Plank", 2, .adductors, secondary: .core, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Plank", 3, .core, availableAt: [.park]),
        .init("Reverse Plank", 3, .core, secondary: .lowerBack, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Push-Up", 3, .chest, secondary: .triceps, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Close-Grip Push-Up", 3, .triceps, secondary: .chest, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Pike Push-Up", 3, .shoulders, secondary: .triceps, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Dip Bar Row", 3, .upperBack, secondary: .lats, secondaryWeight: 0.5, availableAt: [.park]),
        .init("Superman Hold", 3, .lowerBack, secondary: .glutes, secondaryWeight: 0.25, availableAt: [.park]),
        .init("Wall Tibialis Raise", 2, .tibialis, secondary: .calves, secondaryWeight: 0.25, availableAt: [.park]),
        .init("Chin-Up", 3, .biceps, secondary: .lats, secondaryWeight: 0.5, availableAt: [.park])
    ]

    static let approved = basePlan + parkAlternatives

    static func exercises(for venue: TrainingVenue) -> [ExerciseSeed] {
        approved.filter { $0.supports(venue) }
    }

    static func weeklyTargets(from exercises: [ExerciseSeed] = basePlan) -> [Muscle: Double] {
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
