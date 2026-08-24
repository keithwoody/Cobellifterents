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
        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let wednesday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 4))!
        let friday = calendar.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        func draft(_ name: String, _ id: String, _ date: Date, sets: [WorkoutSetDraft] = []) -> WorkoutSessionDraft {
            WorkoutSessionDraft(sourceKind: .strongLiftsCSV, sourceFileName: "SL.csv", sourceRecordID: id, templateName: name, startedAt: date, completedAt: date, bodyWeight: nil, notes: "", sets: sets)
        }
        let squat = WorkoutSetDraft(exerciseID: "squat", exerciseName: "Squat", setNumber: 1, targetReps: 5, completedReps: 5, weight: 100, durationSeconds: nil, note: "")
        let bench = WorkoutSetDraft(exerciseID: "bench", exerciseName: "Bench Press", setNumber: 1, targetReps: 8, completedReps: 8, weight: 50, durationSeconds: nil, note: "")
        let result = ImportToProgramInference.infer(from: [draft("Workout A", "a", monday, sets: [squat]), draft("Workout B", "b", wednesday, sets: [bench]), draft("Workout A", "c", friday)])!
        XCTAssertEqual(result.program.kind, .strongLifts)
        XCTAssertEqual(result.program.workouts.map(\.identity), ["A", "B"])
        XCTAssertEqual(result.program.workouts.map(\.name), ["Workout A", "Workout B"])
        XCTAssertEqual(result.program.workouts[0].exercises.map(\.name), ["Squat"])
        XCTAssertEqual(result.program.workouts[0].exercises[0].targetSets, 1)
        XCTAssertEqual(result.program.workouts[0].exercises[0].targetReps, 5)
        XCTAssertEqual(result.program.workouts[1].exercises[0].targetReps, 8)
        XCTAssertEqual(result.program.trainingDays, [.monday, .wednesday, .friday])
        XCTAssertTrue(result.program.workouts.allSatisfy { $0.assignedDays.isEmpty })
    }

    func testStrongLiftsOnlyAImportCreatesEmptyB() {
        let date = Date(timeIntervalSince1970: 0)
        let set = WorkoutSetDraft(exerciseID: "squat", exerciseName: "Squat", setNumber: 1, targetReps: 5, completedReps: 5, weight: 100, durationSeconds: nil, note: "")
        let draft = WorkoutSessionDraft(sourceKind: .strongLiftsCSV, sourceFileName: "SL.csv", sourceRecordID: "a", templateName: "Workout A", startedAt: date, completedAt: date, bodyWeight: nil, notes: "", sets: [set])
        let result = ImportToProgramInference.infer(from: [draft])!
        XCTAssertEqual(result.program.workouts.map(\.identity), ["A", "B"])
        XCTAssertEqual(result.program.workouts[0].exercises.map(\.name), ["Squat"])
        XCTAssertTrue(result.program.workouts[1].exercises.isEmpty)
        XCTAssertTrue(result.program.workouts[1].assignedDays.isEmpty)
    }

    func testStrongLiftsOnlyBImportCreatesEmptyAAndRecognizesVariants() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let draft = WorkoutSessionDraft(sourceKind: .strongLiftsCSV, sourceFileName: "SL.csv", sourceRecordID: "b", templateName: "StrongLifts Workout B (5x5)", startedAt: date, completedAt: date, bodyWeight: nil, notes: "", sets: [])
        let result = ImportToProgramInference.infer(from: [draft])!
        XCTAssertEqual(result.program.workouts.map(\.identity), ["A", "B"])
        XCTAssertTrue(result.program.workouts[0].exercises.isEmpty)
        XCTAssertTrue(result.program.workouts[0].assignedDays.isEmpty)
        XCTAssertTrue(result.program.workouts[1].exercises.isEmpty)
        XCTAssertEqual(result.program.trainingDays, [.thursday])
    }

    func testEmptyStrongLiftsWorkoutRemainsEditableThroughAddExerciseHelper() {
        let date = Date(timeIntervalSince1970: 0)
        let draft = WorkoutSessionDraft(sourceKind: .strongLiftsCSV, sourceFileName: "SL.csv", sourceRecordID: "a", templateName: "A", startedAt: date, completedAt: date, bodyWeight: nil, notes: "", sets: [])
        var program = ImportToProgramInference.infer(from: [draft])!.program
        XCTAssertEqual(program.workouts.count, 2)
        XCTAssertTrue(program.workouts[0].exercises.isEmpty)
        program.addExercise(to: 0)
        XCTAssertEqual(program.workouts[0].exercises.count, 1)
        XCTAssertEqual(program.workouts[0].exercises[0].name, "New Exercise")
        XCTAssertEqual(program.workouts[0].exercises[0].targetSets, 3)
        XCTAssertEqual(program.workouts[0].exercises[0].targetReps, 5)
    }

    func testEmptyDraftsDoNotInferProgram() {
        XCTAssertNil(ImportToProgramInference.infer(from: []))
    }
}
