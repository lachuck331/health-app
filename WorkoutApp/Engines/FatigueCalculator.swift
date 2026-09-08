import Foundation

struct MuscleExposure: Equatable, Sendable {
    let muscle: Muscle
    let completedAt: Date
    let effectiveSets: Double
}

struct RecoveryObservation: Equatable, Sendable {
    let muscle: Muscle
    let timestamp: Date
    let score: Int
}

struct MuscleState: Equatable, Sendable {
    let muscle: Muscle
    let fatigue: Double
    let readiness: Double
    let hoursSinceLastHit: Double?
    let effectiveSetsLast7Days: Double
    let targetEffectiveSetsLast7Days: Double
}

struct FatigueCalculator: Sendable {
    static let subjectiveReadiness = [1: 10.0, 2: 30, 3: 55, 4: 80, 5: 100]

    func effectiveSets(setCount: Int, contributionWeight: Double) -> Double {
        Double(setCount) * contributionWeight
    }

    func remainingFatigue(for exposure: MuscleExposure, learnedRecoveryHours: Double, at now: Date) -> Double {
        let sets = max(0, exposure.effectiveSets)
        let initialFatigue = min(100, sets * 30)
        let recovery = min(96, max(18, min(96, max(24, learnedRecoveryHours)) * sqrt(sets / 3)))
        let elapsed = max(0, now.timeIntervalSince(exposure.completedAt) / 3600)
        return initialFatigue * max(0, 1 - elapsed / recovery)
    }

    func state(
        for muscle: Muscle,
        exposures: [MuscleExposure],
        checkIns: [RecoveryObservation] = [],
        learnedRecoveryHours: Double = 48,
        targetEffectiveSets: Double,
        at now: Date
    ) -> MuscleState {
        let relevant = exposures.filter { $0.muscle == muscle && $0.completedAt <= now }
        let lastHit = relevant.map(\.completedAt).max()
        let fatigue = min(100, relevant.reduce(0) {
            $0 + remainingFatigue(for: $1, learnedRecoveryHours: learnedRecoveryHours, at: now)
        })
        var readiness = 100 - fatigue

        if let lastHit,
           let checkIn = checkIns
            .filter({ $0.muscle == muscle && $0.timestamp >= lastHit && $0.timestamp <= now })
            .max(by: { $0.timestamp < $1.timestamp }) {
            let age = now.timeIntervalSince(checkIn.timestamp) / 3600
            if age <= 24, let subjective = Self.subjectiveReadiness[min(5, max(1, checkIn.score))] {
                let weight = 0.5 * max(0, 1 - age / 24)
                readiness = readiness * (1 - weight) + subjective * weight
            }
        }

        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 3600)
        let weeklySets = relevant
            .filter { $0.completedAt >= sevenDaysAgo }
            .reduce(0) { $0 + $1.effectiveSets }
        let hours = lastHit.map { max(0, now.timeIntervalSince($0) / 3600) }
        return MuscleState(
            muscle: muscle,
            fatigue: min(100, max(0, 100 - readiness)),
            readiness: min(100, max(0, readiness)),
            hoursSinceLastHit: hours,
            effectiveSetsLast7Days: weeklySets,
            targetEffectiveSetsLast7Days: targetEffectiveSets
        )
    }
}
