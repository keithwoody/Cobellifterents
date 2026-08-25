import XCTest
@testable import Cobellifterents

final class WorkoutSessionRecoveryTests: XCTestCase {
    func testEmptyIncompleteSessionIsIgnored() {
        let emptySession = WorkoutSession(templateID: .strongLiftsA, templateName: "Workout A")

        XCTAssertNil(WorkoutSessionRecovery.resumableSession(from: [emptySession]))
    }

    func testNonEmptyIncompleteSessionIsResumed() {
        let session = WorkoutSession.seeded(from: StrongLiftsTemplates.all[0], history: [])

        XCTAssertIdentical(WorkoutSessionRecovery.resumableSession(from: [session]), session)
    }

    func testCompletedSessionsAreIgnored() {
        let completedSession = WorkoutSession(
            templateID: .strongLiftsA,
            templateName: "Workout A",
            completedAt: Date(),
            sets: [WorkoutSetRecord(
                exerciseID: "squat",
                exerciseName: "Squat",
                setNumber: 1,
                targetReps: 5,
                weight: 45
            )]
        )

        XCTAssertNil(WorkoutSessionRecovery.resumableSession(from: [completedSession]))
    }
}