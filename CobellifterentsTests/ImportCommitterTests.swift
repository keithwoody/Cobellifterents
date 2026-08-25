import SwiftData
import XCTest
@testable import Cobellifterents

final class ImportCommitterTests: XCTestCase {
    func testCommitInsertsRawRecordsAndNativeSessionsOnlyOnce() throws {
        let schema = Schema([WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let csv = """
Date (yyyy/mm/dd),Workout,Workout Name,Program Name,Body Weight (LB),Exercise,Sets×Reps,Sets×Time,Top Set (Reps×LB),e1RM (LB),Reps,Volume (LB),Workout Volume (LB),Duration (hours),Start Time (h:mm),End Time (h:mm),Notes,Set 1 (Reps),Set 1 (LB),Set 2 (Reps),Set 2 (LB),Set 3 (Reps),Set 3 (LB),Set 4 (Reps),Set 4 (LB),Set 5 (Reps),Set 5 (LB)
2026/03/03,1,Workout A,Quarantine,175,Dumbbell Lunge,5×12,,12×20,31.9,60,2100,9060.0,1.2789,10:02 AM,11:55 AM,,12,20,12,20,12,17.5,12,15,12,15
"""
        let preview = CSVWorkoutImporter.previewStrongLiftsCSV(csv, sourceFileName: "StrongLifts.csv")

        let first = try ImportCommitter.commit(preview, into: context)
        XCTAssertEqual(first.insertedRawRecords, 1)
        XCTAssertEqual(first.skippedRawRecords, 0)
        XCTAssertEqual(first.insertedWorkoutSessions, 1)
        XCTAssertEqual(first.skippedWorkoutSessions, 0)

        let second = try ImportCommitter.commit(preview, into: context)
        XCTAssertEqual(second.insertedRawRecords, 0)
        XCTAssertEqual(second.skippedRawRecords, 1)
        XCTAssertEqual(second.insertedWorkoutSessions, 0)
        XCTAssertEqual(second.skippedWorkoutSessions, 1)

        let rawRecords = try context.fetch(FetchDescriptor<ImportedRawRecord>())
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(rawRecords.count, 1)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].isImported, true)
        XCTAssertEqual(sessions[0].sets.count, 5)
    }

    func testImportedSessionPreservesFirstSeenExerciseOrder() throws {
        let csv = """
Date (yyyy/mm/dd),Workout,Workout Name,Program Name,Body Weight (LB),Exercise,Sets×Reps,Sets×Time,Top Set (Reps×LB),e1RM (LB),Reps,Volume (LB),Workout Volume (LB),Duration (hours),Start Time (h:mm),End Time (h:mm),Notes,Set 1 (Reps),Set 1 (LB),Set 2 (Reps),Set 2 (LB),Set 3 (Reps),Set 3 (LB),Set 4 (Reps),Set 4 (LB),Set 5 (Reps),Set 5 (LB)
2026/03/03,1,Workout A,Quarantine,175,Dumbbell Lunge,5×12,,12×20,31.9,60,2100,9060.0,1.2789,10:02 AM,11:55 AM,,12,20,12,20,12,17.5,12,15,12,15
2026/03/03,1,Workout A,Quarantine,175,Dumbbell Bench Press,5×12,,12×22.5,35.9,60,2460,9060.0,1.2789,10:02 AM,11:55 AM,,12,20,12,20,12,20,12,20,12,22.5
2026/03/03,1,Workout A,Quarantine,175,Dumbbell Row,5×12,,12×30,47.9,60,3600,9060.0,1.2789,10:02 AM,11:55 AM,,12,30,12,30,12,30,12,30,12,30
"""
        let preview = CSVWorkoutImporter.previewStrongLiftsCSV(csv, sourceFileName: "StrongLifts.csv")
        let session = WorkoutImportMapper.importedSession(from: preview.workoutSessions[0])

        let exerciseOrder = Dictionary(grouping: session.sets, by: \.exerciseID)
            .values
            .compactMap { sets -> (String, Int)? in
                guard let first = sets.first, let displayOrder = first.displayOrder else { return nil }
                return (first.exerciseName, displayOrder)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)

        XCTAssertEqual(exerciseOrder, ["Dumbbell Lunge", "Dumbbell Bench Press", "Dumbbell Row"])
    }

    func testATGCommitIsIdempotentAndUsesATGTemplateIdentity() throws {
        let schema = Schema([WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let csv = "workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Strength Training,ATG Pushup,2024-01-11,10,0,lbs,30,30000,\n" +
            "Strength Training,ATG Split Squat,,5,0,lbs,0,0,\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")
        let first = try ImportCommitter.commit(preview, into: context, createOrUpdateProgram: false)
        let second = try ImportCommitter.commit(preview, into: context, createOrUpdateProgram: false)
        XCTAssertEqual(first.insertedRawRecords, 2)
        XCTAssertEqual(first.insertedWorkoutSessions, 1)
        XCTAssertEqual(second.insertedRawRecords, 0)
        XCTAssertEqual(second.insertedWorkoutSessions, 0)
        let session = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertEqual(session.templateID, .atgImported)
        XCTAssertEqual(session.importSourceFileName, "ATG.csv")
        XCTAssertEqual(session.sets.first?.durationSeconds, 30)
    }

    func testATGGeneratedProgramSignalsMissingProgramAssignment() {
        let csv = "workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Strength Training,ATG Pushup,2024-01-11,10,0,lbs,30,30000,\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")
        let inferred = ImportToProgramInference.infer(from: preview.workoutSessions, sourceKind: .atgCSV)
        XCTAssertEqual(inferred?.program.name, "Imported ATG (Program assignment needed)")
        XCTAssertEqual(preview.workoutSessions.first?.programAssignment, .unassignedAmbiguous)
    }
}
