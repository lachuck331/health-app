import XCTest
import SwiftData
@testable import WorkoutApp

final class EngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)
    private let fatigue = FatigueCalculator()

    func testPrimaryAndSecondaryEffectiveSets() {
        XCTAssertEqual(fatigue.effectiveSets(setCount: 3, contributionWeight: 1), 3)
        XCTAssertEqual(fatigue.effectiveSets(setCount: 3, contributionWeight: 0.5), 1.5)
    }

    func testFatigueDecay() {
        let exposure = MuscleExposure(muscle: .quads, completedAt: now.addingTimeInterval(-24 * 3600), effectiveSets: 3)
        XCTAssertEqual(fatigue.remainingFatigue(for: exposure, learnedRecoveryHours: 48, at: now), 45, accuracy: 0.001)
    }

    func testOverlappingWorkoutsAreSummedAndClamped() {
        let exposures = [1.0, 12.0].map { MuscleExposure(muscle: .chest, completedAt: now.addingTimeInterval(-$0 * 3600), effectiveSets: 3) }
        let state = fatigue.state(for: .chest, exposures: exposures, targetEffectiveSets: 6, at: now)
        XCTAssertEqual(state.fatigue, 100)
        XCTAssertEqual(state.readiness, 0)
    }

    func testFreshCheckInBlendsAtFiftyPercent() {
        let exposure = MuscleExposure(muscle: .quads, completedAt: now.addingTimeInterval(-48 * 3600), effectiveSets: 3)
        let checkIn = RecoveryObservation(muscle: .quads, timestamp: now, score: 1)
        let state = fatigue.state(for: .quads, exposures: [exposure], checkIns: [checkIn], targetEffectiveSets: 3, at: now)
        XCTAssertEqual(state.readiness, 55, accuracy: 0.001)
    }

    func testCheckInBeforeMostRecentWorkoutIsIgnored() {
        let exposure = MuscleExposure(muscle: .quads, completedAt: now.addingTimeInterval(-1 * 3600), effectiveSets: 3)
        let checkIn = RecoveryObservation(muscle: .quads, timestamp: now.addingTimeInterval(-2 * 3600), score: 5)
        let state = fatigue.state(for: .quads, exposures: [exposure], checkIns: [checkIn], targetEffectiveSets: 3, at: now)
        XCTAssertEqual(state.readiness, 11.875, accuracy: 0.001)
    }

    func testRollingSevenDayVolume() {
        let exposures = [6.0, 8.0].map { MuscleExposure(muscle: .biceps, completedAt: now.addingTimeInterval(-$0 * 24 * 3600), effectiveSets: 2) }
        let state = fatigue.state(for: .biceps, exposures: exposures, targetEffectiveSets: 4.5, at: now)
        XCTAssertEqual(state.effectiveSetsLast7Days, 2)
    }

    func testWeeklyTargetsAreDerivedFromExercises() {
        let targets = ExerciseSeed.weeklyTargets()
        XCTAssertEqual(targets[.glutes], 4)
        XCTAssertEqual(targets[.triceps], 5.5)
        XCTAssertEqual(targets[.lats], 4.5)
    }

    func testParkAlternativesDoNotInflateWeeklyTargets() {
        XCTAssertEqual(ExerciseSeed.weeklyTargets(), ExerciseSeed.weeklyTargets(from: ExerciseSeed.basePlan))
        XCTAssertNotEqual(ExerciseSeed.weeklyTargets(), ExerciseSeed.weeklyTargets(from: ExerciseSeed.approved))
    }

    func testVenueCatalogIsUniqueAndCorrectlyFiltered() {
        XCTAssertEqual(Set(ExerciseSeed.approved.map(\.name)).count, ExerciseSeed.approved.count)

        for venue in TrainingVenue.allCases {
            let catalog = ExerciseSeed.exercises(for: venue)
            XCTAssertFalse(catalog.isEmpty)
            XCTAssertTrue(catalog.allSatisfy { $0.supports(venue) })
        }

        XCTAssertTrue(ExerciseSeed.exercises(for: .gym).contains { $0.name == "Pull Ups" })
        XCTAssertTrue(ExerciseSeed.exercises(for: .park).contains { $0.name == "Pull Ups" })
        XCTAssertTrue(ExerciseSeed.exercises(for: .gym).contains { $0.name == "Dip Bar Row" })
        XCTAssertTrue(ExerciseSeed.exercises(for: .park).contains { $0.name == "Dip Bar Row" })

        let parkCatalog = ExerciseSeed.exercises(for: .park)
        XCTAssertGreaterThan(
            parkCatalog.filter { $0.supports(.gym) }.count,
            parkCatalog.count / 2,
            "Most Park exercises should also be available at the gym"
        )
    }

    func testParkCatalogHasPrimaryMovementForEveryMuscle() {
        let parkExercises = ExerciseSeed.exercises(for: .park)
        for muscle in Muscle.allCases {
            XCTAssertTrue(
                parkExercises.contains { $0.primaryMuscle == muscle },
                "Missing primary Park exercise for \(muscle.rawValue)"
            )
        }
    }

    func testRequestedParkMovementsArePresent() {
        let parkNames = Set(ExerciseSeed.exercises(for: .park).map(\.name))
        let expected = [
            "Pull Ups", "Dips", "Push-Up", "Bodyweight Squat", "Plank",
            "Reverse Plank", "Hollow Body Hold", "Dip Bar Row"
        ]
        XCTAssertTrue(Set(expected).isSubset(of: parkNames))
    }

    func testRecommendationRankingRewardsReadiness() {
        let states = [makeState(.quads, readiness: 90), makeState(.chest, readiness: 50)]
        let exercises = [ExerciseSeed("Squat", 3, .quads), ExerciseSeed("Press", 3, .chest)]
        let results = RecommendationEngine().recommendations(exercises: exercises, states: states)
        XCTAssertEqual(results.first?.exercise.name, "Squat")
    }

    func testSecondaryMusclePenalty() {
        let states = [makeState(.chest, readiness: 80), makeState(.triceps, readiness: 40)]
        let dips = ExerciseSeed("Dips", 3, .chest, secondary: .triceps, secondaryWeight: 0.5)
        let result = RecommendationEngine().recommendations(exercises: [dips], states: states)[0]
        XCTAssertEqual(result.secondaryPenalty, 5)
        XCTAssertNotNil(result.explanation)
    }

    func testReadinessAndTimeRanks() {
        let states = [
            makeState(.quads, readiness: 90, hours: 24),
            makeState(.chest, readiness: 70, hours: 72),
            makeState(.lats, readiness: 50, hours: 48)
        ]
        let ranks = RecommendationEngine().rankMuscles(states)
        XCTAssertEqual(ranks[.quads]?.readinessRank, 1)
        XCTAssertEqual(ranks[.chest]?.timeSinceLastHitRank, 1)
    }

    func testNeverTrainedMuscleGetsHighestTimePriorityAndFullTimeScore() {
        let states = [makeState(.quads, readiness: 80, hours: nil), makeState(.chest, readiness: 80, hours: 20)]
        let engine = RecommendationEngine()
        XCTAssertEqual(engine.rankMuscles(states)[.quads]?.timeSinceLastHitRank, 1)
        let exercises = [ExerciseSeed("Squat", 3, .quads), ExerciseSeed("Press", 3, .chest)]
        XCTAssertEqual(engine.recommendations(exercises: exercises, states: states).first?.exercise.name, "Squat")
    }

    func testTopThreePrefersDifferentPrimaryMuscles() {
        let states = [
            makeState(.quads, readiness: 100, hours: nil),
            makeState(.chest, readiness: 95, hours: nil),
            makeState(.lats, readiness: 90, hours: nil)
        ]
        let exercises = [
            ExerciseSeed("Hack Squat", 3, .quads),
            ExerciseSeed("Leg Press", 3, .quads),
            ExerciseSeed("Dips", 3, .chest),
            ExerciseSeed("Pull Ups", 3, .lats)
        ]
        let results = RecommendationEngine().topThree(exercises: exercises, states: states)
        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(Set(results.map(\.exercise.primaryMuscle)).count, 3)
    }

    @MainActor
    func testSavedWorkoutFeedsReadinessAndVolumeSnapshot() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: MuscleProfile.self,
            ExerciseDefinition.self,
            Workout.self,
            WorkoutExercise.self,
            WorkoutSet.self,
            RecoveryCheckIn.self,
            MuscleExerciseSelection.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let definition = ExerciseDefinition(seed: ExerciseSeed.approved.first { $0.name == "Hack Squat" }!)
        let workout = Workout(startedAt: now.addingTimeInterval(-3600), finishedAt: now.addingTimeInterval(-3600))
        let loggedExercise = WorkoutExercise(exercise: definition, workout: workout, order: 0)
        workout.exercises.append(loggedExercise)
        for number in 1...3 {
            loggedExercise.sets.append(WorkoutSet(setNumber: number, weight: 225, reps: 8, workoutExercise: loggedExercise))
        }
        context.insert(definition)
        context.insert(workout)
        try context.save()

        let stored = try context.fetch(FetchDescriptor<Workout>())
        let states = TrainingSnapshotBuilder.muscleStates(workouts: stored, profiles: [], checkIns: [], now: now)
        let quads = try XCTUnwrap(states.first { $0.muscle == .quads })
        let glutes = try XCTUnwrap(states.first { $0.muscle == .glutes })
        XCTAssertEqual(quads.effectiveSetsLast7Days, 3)
        XCTAssertEqual(glutes.effectiveSetsLast7Days, 1.5)
        XCTAssertLessThan(quads.readiness, 20)
        XCTAssertEqual(workout.venue, .gym)
    }

    func testExerciseDefinitionStoresNonExclusiveVenueAvailability() {
        let definition = ExerciseDefinition(seed: ExerciseSeed.basePlan.first { $0.name == "Dips" }!)
        XCTAssertTrue(definition.supports(.gym))
        XCTAssertTrue(definition.supports(.park))
    }

    func testCustomExerciseCanBeArchivedAndConvertedForRecommendations() {
        let definition = ExerciseDefinition(
            name: "Test Movement",
            targetSetsPerWeek: 4,
            primaryMuscle: .shoulders,
            secondaryMuscle: .triceps,
            isGymAvailable: true,
            isParkAvailable: true
        )
        XCTAssertFalse(definition.isArchived)
        XCTAssertEqual(definition.seed.availableAt, [.gym, .park])
        XCTAssertEqual(definition.seed.secondaryWeight, 0.5)

        definition.isArchived = true
        XCTAssertTrue(definition.isArchived)
    }

    func testEveryMuscleHasAnApprovedExercise() {
        for muscle in Muscle.allCases {
            XCTAssertTrue(
                ExerciseSeed.approved.contains {
                    $0.primaryMuscle == muscle || $0.secondaryMuscle == muscle
                },
                "Missing exercise for \(muscle.rawValue)"
            )
        }
    }

    private func makeState(_ muscle: Muscle, readiness: Double, hours: Double? = 72) -> MuscleState {
        MuscleState(muscle: muscle, fatigue: 100 - readiness, readiness: readiness, hoursSinceLastHit: hours, effectiveSetsLast7Days: 0, targetEffectiveSetsLast7Days: 3)
    }
}
