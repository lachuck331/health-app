import Foundation
import SwiftData

@Model
final class MuscleProfile {
    @Attribute(.unique) var name: String
    var defaultRecoveryHours: Double
    private var storedLearnedRecoveryHours: Double

    var learnedRecoveryHours: Double {
        get { storedLearnedRecoveryHours }
        set { storedLearnedRecoveryHours = min(96, max(24, newValue)) }
    }

    var muscle: Muscle? { Muscle(rawValue: name) }

    init(muscle: Muscle, defaultRecoveryHours: Double = 48, learnedRecoveryHours: Double = 48) {
        name = muscle.rawValue
        self.defaultRecoveryHours = defaultRecoveryHours
        storedLearnedRecoveryHours = min(96, max(24, learnedRecoveryHours))
    }
}
