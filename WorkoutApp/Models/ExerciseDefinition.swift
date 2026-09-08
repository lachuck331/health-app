import Foundation
import SwiftData

@Model
final class ExerciseDefinition {
    @Attribute(.unique) var name: String
    var targetSetsPerWeek: Double
    var primaryMuscleName: String
    var primaryWeight: Double
    var secondaryMuscleName: String?
    var secondaryWeight: Double?
    var isGymAvailable: Bool = true
    var isParkAvailable: Bool = false

    var primaryMuscle: Muscle { Muscle(rawValue: primaryMuscleName)! }
    var secondaryMuscle: Muscle? { secondaryMuscleName.flatMap(Muscle.init(rawValue:)) }

    init(seed: ExerciseSeed) {
        name = seed.name
        targetSetsPerWeek = seed.targetSetsPerWeek
        primaryMuscleName = seed.primaryMuscle.rawValue
        primaryWeight = seed.primaryWeight
        secondaryMuscleName = seed.secondaryMuscle?.rawValue
        secondaryWeight = seed.secondaryWeight
        isGymAvailable = seed.supports(.gym)
        isParkAvailable = seed.supports(.park)
    }

    func update(from seed: ExerciseSeed) {
        targetSetsPerWeek = seed.targetSetsPerWeek
        primaryMuscleName = seed.primaryMuscle.rawValue
        primaryWeight = seed.primaryWeight
        secondaryMuscleName = seed.secondaryMuscle?.rawValue
        secondaryWeight = seed.secondaryWeight
        isGymAvailable = seed.supports(.gym)
        isParkAvailable = seed.supports(.park)
    }

    func supports(_ venue: TrainingVenue) -> Bool {
        switch venue {
        case .gym: isGymAvailable
        case .park: isParkAvailable
        }
    }
}
