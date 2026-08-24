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
}
