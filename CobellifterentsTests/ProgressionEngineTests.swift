import XCTest
@testable import Cobellifterents

final class ProgressionEngineTests: XCTestCase {
    func testSuccessfulWorkoutAddsIncrement() {
        let next = ProgressionEngine.nextWeight(
            currentWeight: 100,
            consecutiveFailures: 0,
            performance: ExercisePerformance(completedAllTargetReps: true),
            rule: ProgressionRule(increment: 5)
        )
        XCTAssertEqual(next, 105)
    }

    func testFirstFailureRepeatsWeight() {
        let next = ProgressionEngine.nextWeight(
            currentWeight: 100,
            consecutiveFailures: 0,
            performance: ExercisePerformance(completedAllTargetReps: false),
            rule: ProgressionRule(increment: 5)
        )
        XCTAssertEqual(next, 100)
    }

    func testThirdFailureDeloadsTenPercentRoundedToFive() {
        let next = ProgressionEngine.nextWeight(
            currentWeight: 135,
            consecutiveFailures: 2,
            performance: ExercisePerformance(completedAllTargetReps: false),
            rule: ProgressionRule(increment: 5, minimumWeight: 45)
        )
        XCTAssertEqual(next, 120)
    }

    func testStrongLiftsDefaultsAlternateAfterWorkoutA() {
        XCTAssertEqual(StrongLiftsTemplates.template(after: .strongLiftsA).id, .strongLiftsB)
        XCTAssertEqual(StrongLiftsTemplates.template(after: .strongLiftsB).id, .strongLiftsA)
        XCTAssertEqual(StrongLiftsTemplates.template(after: nil).id, .strongLiftsA)
    }

    func testSeededWorkoutPreservesTemplateExerciseOrder() {
        let session = WorkoutSession.seeded(from: StrongLiftsTemplates.all[0], history: [])
        let exerciseOrder = Dictionary(grouping: session.sets, by: \.exerciseID)
            .values
            .compactMap { sets -> (String, Int)? in
                guard let first = sets.first, let displayOrder = first.displayOrder else { return nil }
                return (first.exerciseName, displayOrder)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)

        XCTAssertEqual(exerciseOrder, ["Squat", "Bench Press", "Barbell Row"])
    }
}
