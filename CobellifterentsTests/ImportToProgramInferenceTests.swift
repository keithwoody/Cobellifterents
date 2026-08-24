import XCTest
@testable import Cobellifterents

final class ImportToProgramInferenceTests: XCTestCase {
    func testInferencePreservesTemplateExerciseOrderPrescriptionAndDays() {
        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 4))!
        func draft(_ date: Date, _ template: String, _ id: String) -> WorkoutSessionDraft {
            WorkoutSessionDraft(sourceKind: .atgCSV, sourceFileName: "mobility.csv", sourceRecordID: id, templateName: template, startedAt: date, completedAt: date, bodyWeight: nil, notes: "", sets: [
                WorkoutSetDraft(exerciseID: "a", exerciseName: "Squat", setNumber: 1, targetReps: 8, completedReps: 8, weight: 0, durationSeconds: nil, note: ""),
                WorkoutSetDraft(exerciseID: "b", exerciseName: "Calf Raise", setNumber: 1, targetReps: 12, completedReps: 12, weight: 0, durationSeconds: nil, note: ""),
                WorkoutSetDraft(exerciseID: "a", exerciseName: "Squat", setNumber: 2, targetReps: 8, completedReps: 8, weight: 0, durationSeconds: nil, note: "")
            ])
        }
        let result = ImportToProgramInference.infer(from: [draft(monday, "Lower", "1"), draft(wednesday, "Lower", "2")])!
        XCTAssertEqual(result.program.kind, .atg)
        XCTAssertEqual(result.program.workouts[0].exercises.map(\.name), ["Squat", "Calf Raise"])
        XCTAssertEqual(result.program.workouts[0].exercises.map(\.targetSets), [2, 1])
        XCTAssertEqual(result.program.workouts[0].assignedDays, [.monday, .wednesday])
        XCTAssertTrue(result.needsScheduleEditing)
    }

    func testStrongLiftsTemplatesRetainABIdentity() {
        let date = Date(timeIntervalSince1970: 0)
        func draft(_ name: String, _ id: String) -> WorkoutSessionDraft {
            WorkoutSessionDraft(sourceKind: .strongLiftsCSV, sourceFileName: "SL.csv", sourceRecordID: id, templateName: name, startedAt: date, completedAt: date, bodyWeight: nil, notes: "", sets: [])
        }
        let result = ImportToProgramInference.infer(from: [draft("Workout A", "a"), draft("Workout B", "b")])!
        XCTAssertEqual(result.program.kind, .strongLifts)
        XCTAssertEqual(result.program.workouts.map(\.identity), ["A", "B"])
    }

    func testEmptyDraftsDoNotInferProgram() {
        XCTAssertNil(ImportToProgramInference.infer(from: []))
    }
}
