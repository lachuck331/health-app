import Foundation
import SwiftData

@Model
final class MuscleExerciseSelection {
    @Attribute(.unique) var id: UUID
    var muscleName: String
    var exerciseName: String
    var order: Int

    var muscle: Muscle { Muscle(rawValue: muscleName)! }

    init(id: UUID = UUID(), muscle: Muscle, exerciseName: String, order: Int) {
        self.id = id
        muscleName = muscle.rawValue
        self.exerciseName = exerciseName
        self.order = order
    }
}
