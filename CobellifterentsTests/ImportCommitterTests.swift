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

    func testATGGeneratedProgramsOnlyUseExplicitKnownAssignments() {
        let csv = "workout_type,program,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Strength Training,Ankle Ability Zero,ATG Pushup,2024-01-11,10,0,lbs,30,30000,\n" +
            "Strength Training,Unknown Plan,ATG Split Squat,2024-01-12,5,0,lbs,0,0,\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")
        let programs = ATGProgramPlanner.placeholderPrograms(from: preview.workoutSessions)
        XCTAssertEqual(programs.map(\.name), ["Ankle Ability Zero"])
        XCTAssertEqual(preview.workoutSessions.map(\.programAssignment), [.ankleAbilityZero, .unassignedAmbiguous])
    }

    func testIndividualAssignmentPersistsWithoutChangingImportData() throws {
        let schema = Schema([WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let csv = "workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Strength Training,ATG Pushup,2024-01-11,10,0,lbs,30,30000,\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")
        _ = try ImportCommitter.commit(preview, into: context, createOrUpdateProgram: false)
        let session = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutSession>()).first)
        let sourceID = session.importSourceRecordID
        let setCount = session.sets.count
        let program = Program.new(kind: .atg, name: "Mobility")

        XCTAssertTrue(try WorkoutProgramAssignment.assign(session, to: program, in: context))
        let reloaded = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertEqual(reloaded.programAssignmentID, program.id)
        XCTAssertEqual(reloaded.programAssignmentRawValue, "Mobility")
        XCTAssertEqual(reloaded.programAssignmentEvidence, "manual")
        XCTAssertEqual(reloaded.importSourceRecordID, sourceID)
        XCTAssertEqual(reloaded.sets.count, setCount)
    }

    func testAssignmentToUnpersistedDefaultResolvesAfterRepositoryReload() throws {
        let schema = Schema([WorkoutSession.self, WorkoutSetRecord.self, ImportedRawRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let csv = "workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Strength Training,ATG Pushup,2024-01-11,10,0,lbs,30,30000,\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")
        _ = try ImportCommitter.commit(preview, into: context, createOrUpdateProgram: false)
        let session = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutSession>()).first)

        let firstRepository = ProgramsRepository(defaults: UserDefaults(suiteName: "ImportCommitterTests.default-relaunch-1")!)
        let selectedDefault = try XCTUnwrap(firstRepository.load().first(where: { $0.kind == .atg }))
        XCTAssertTrue(try WorkoutProgramAssignment.assign(session, to: selectedDefault, in: context))

        // A fresh repository instance models the next process launch while the
        // imported session retains the assignment UUID in SwiftData.
        let secondRepository = ProgramsRepository(defaults: UserDefaults(suiteName: "ImportCommitterTests.default-relaunch-2")!)
        let reloadedDefault = try XCTUnwrap(secondRepository.load().first(where: { $0.kind == .atg }))
        XCTAssertEqual(session.programAssignmentID, reloadedDefault.id)
        XCTAssertEqual(WorkoutProgramAssignment.program(for: session, in: secondRepository.load()), reloadedDefault)
    }

    func testBulkAssignmentClearReassignmentAndPersistence() throws {
        let schema = Schema([WorkoutSession.self, WorkoutSetRecord.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let sessions = (0..<3).map { index in
            let session = WorkoutSession(templateID: .atgImported, templateName: "Imported \(index)")
            session.importSourceRecordID = "source-\(index)"
            session.sets = [WorkoutSetRecord(exerciseID: "e", exerciseName: "Exercise", setNumber: 1, targetReps: 5, weight: 0)]
            context.insert(session)
            return session
        }
        try context.save()
        let first = Program.new(kind: .atg, name: "First")
        let second = Program.new(kind: .atg, name: "Second")

        XCTAssertEqual(try WorkoutProgramAssignment.assign(sessions, to: first, in: context), 3)
        XCTAssertEqual(try WorkoutProgramAssignment.assign(Array(sessions.prefix(2)), to: second, in: context), 2)
        XCTAssertEqual(try WorkoutProgramAssignment.clear([sessions[2]], in: context), 1)

        let reloaded = try context.fetch(FetchDescriptor<WorkoutSession>()).sorted { $0.importSourceRecordID! < $1.importSourceRecordID! }
        XCTAssertEqual(reloaded[0].programAssignmentID, second.id)
        XCTAssertEqual(reloaded[1].programAssignmentID, second.id)
        XCTAssertNil(reloaded[2].programAssignmentID)
        XCTAssertEqual(reloaded.map { $0.importSourceRecordID }, ["source-0", "source-1", "source-2"])
        XCTAssertEqual(reloaded.flatMap { $0.sets }.count, 3)
    }

    func testNonImportedWorkoutCannotBeAssigned() throws {
        let schema = Schema([WorkoutSession.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)
        let session = WorkoutSession(templateID: .strongLiftsA, templateName: "Workout A")
        let program = Program.new(kind: .strongLifts, name: "Strong")
        XCTAssertThrowsError(try WorkoutProgramAssignment.assign(session, to: program, in: context)) { error in
            XCTAssertEqual(error as? WorkoutProgramAssignmentError, .workoutNotImported)
        }
    }

    func testATGGeneratedProgramSignalsMissingProgramAssignment() {
        let csv = "workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Strength Training,ATG Pushup,2024-01-11,10,0,lbs,30,30000,\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")
        let programs = ATGProgramPlanner.placeholderPrograms(from: preview.workoutSessions)
        XCTAssertEqual(programs.map(\.name), ["Ankle Ability Zero"])
        XCTAssertEqual(preview.workoutSessions.map(\.programAssignment), [.ankleAbilityZero, .unassignedAmbiguous])
    }
}
