import XCTest
@testable import Cobellifterents

final class WorkoutDisplayNamingTests: XCTestCase {
    func testCombinesCustomProgramAndWorkoutNames() {
        XCTAssertEqual(
            WorkoutDisplayNaming.combined(programName: "My StrongLifts", workoutName: "Workout A"),
            "My StrongLifts • Workout A"
        )
    }

    func testBuiltInStrongLiftsLegacySessionGetsProgramFallback() {
        let session = WorkoutSession(templateID: .strongLiftsA, templateName: "Workout A")
        XCTAssertEqual(WorkoutDisplayNaming.displayName(for: session), "StrongLifts 5×5 • Workout A")

        let sessionB = WorkoutSession(templateID: .strongLiftsB, templateName: "Workout B")
        XCTAssertEqual(WorkoutDisplayNaming.displayName(for: sessionB), "StrongLifts 5×5 • Workout B")
    }

    func testNonStrongLiftsNameRemainsUnchanged() {
        XCTAssertEqual(
            WorkoutDisplayNaming.displayName(programName: nil, workoutName: "ATG Training", templateID: nil),
            "ATG Training"
        )
    }

    func testImportedATGSessionShowsExplicitProgramAssignment() {
        let session = WorkoutSession(templateID: .atgImported, templateName: "ATG Mobility")
        session.programAssignmentRawValue = ImportProgramAssignment.kneeAbilityZero.rawValue

        XCTAssertEqual(WorkoutDisplayNaming.displayName(for: session), "Knee Ability Zero • ATG Mobility")
    }

    func testImportedATGProgramsAllDisplayCorrectly() {
        for assignment in [ImportProgramAssignment.kneeAbilityZero, .ankleAbilityZero, .backAbilityZero] {
            let session = WorkoutSession(templateID: .atgImported, templateName: "ATG Mobility")
            session.programAssignmentRawValue = assignment.rawValue
            XCTAssertEqual(WorkoutDisplayNaming.displayName(for: session), "\(assignment.displayName) • ATG Mobility")
        }
    }

    func testAmbiguousImportedATGSessionDoesNotInventProgramAssignment() {
        let session = WorkoutSession(templateID: .atgImported, templateName: "ATG Mobility")
        session.programAssignmentRawValue = ImportProgramAssignment.unassignedAmbiguous.rawValue

        XCTAssertEqual(WorkoutDisplayNaming.displayName(for: session), "ATG Mobility")
    }

    func testSeededSessionKeepsCombinedCustomIdentityForPersistence() throws {
        let workout = ProgramWorkout(identity: "A", name: "Workout A", exercises: [])
        let template = try XCTUnwrap(ProgramWorkoutConversion.template(from: workout, programName: "Custom Program"))
        let session = WorkoutSession.seeded(from: template, history: [])

        XCTAssertEqual(session.templateName, "Custom Program • Workout A")
        XCTAssertEqual(WorkoutDisplayNaming.displayName(for: session), "Custom Program • Workout A")
    }
}
