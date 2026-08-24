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
}
