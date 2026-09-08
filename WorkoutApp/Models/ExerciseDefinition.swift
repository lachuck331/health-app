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

    var primaryMuscle: Muscle { Muscle(rawValue: primaryMuscleName)! }
    var secondaryMuscle: Muscle? { secondaryMuscleName.flatMap(Muscle.init(rawValue:)) }

    init(seed: ExerciseSeed) {
        name = seed.name
        targetSetsPerWeek = seed.targetSetsPerWeek
        primaryMuscleName = seed.primaryMuscle.rawValue
        primaryWeight = seed.primaryWeight
        secondaryMuscleName = seed.secondaryMuscle?.rawValue
        secondaryWeight = seed.secondaryWeight
    }
}
