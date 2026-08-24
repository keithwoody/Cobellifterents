import XCTest
@testable import Cobellifterents

final class CSVWorkoutImporterTests: XCTestCase {
    func testStrongLiftsImportPreservesRawRowsAndCreatesNativeSession() throws {
        let csv = """
Date (yyyy/mm/dd),Workout,Workout Name,Program Name,Body Weight (LB),Exercise,Sets×Reps,Sets×Time,Top Set (Reps×LB),e1RM (LB),Reps,Volume (LB),Workout Volume (LB),Duration (hours),Start Time (h:mm),End Time (h:mm),Notes,Set 1 (Reps),Set 1 (LB),Set 2 (Reps),Set 2 (LB),Set 3 (Reps),Set 3 (LB),Set 4 (Reps),Set 4 (LB),Set 5 (Reps),Set 5 (LB)
2026/03/03,1,Workout A,Quarantine,175,Dumbbell Lunge,5×12,,12×20,31.9,60,2100,9060.0,1.2789,10:02 AM,11:55 AM,,12,20,12,20,12,17.5,12,15,12,15
2026/03/03,1,Workout A,Quarantine,175,Dumbbell Bench Press,5×12,,12×22.5,35.9,60,2460,9060.0,1.2789,10:02 AM,11:55 AM,,12,20,12,20,12,20,12,20,12,22.5
"""
        let preview = CSVWorkoutImporter.previewStrongLiftsCSV(csv, sourceFileName: "StrongLifts.csv")

        XCTAssertEqual(preview.rawRecords.count, 2)
        XCTAssertEqual(preview.workoutSessions.count, 1)
        XCTAssertEqual(preview.issues, [])
        XCTAssertEqual(preview.workoutSessions[0].templateName, "Workout A")
        XCTAssertEqual(preview.workoutSessions[0].bodyWeight, 175)
        XCTAssertEqual(preview.workoutSessions[0].sets.count, 10)
        XCTAssertEqual(preview.workoutSessions[0].sets.first?.exerciseName, "Dumbbell Lunge")
        XCTAssertEqual(preview.workoutSessions[0].sets.first?.completedReps, 12)
        XCTAssertEqual(preview.workoutSessions[0].sets.first?.weight, 20)
    }

    func testATGImportKeepsBlankDateRowsAsRawOnly() {
        let csv = """
workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note
Strength Training,ATG Pushup,,10,,lbs,,,
Strength Training,ATG Split Squat,2024-01-11,5,0,lbs,0,0,3x10 instead of 5x5
"""
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")

        XCTAssertEqual(preview.rawRecords.count, 2)
        XCTAssertEqual(preview.workoutSessions.count, 1)
        XCTAssertEqual(preview.issues.count, 1)
        XCTAssertEqual(preview.issues[0].message, "ATG row has no date; preserving raw provenance only")
        XCTAssertEqual(preview.workoutSessions[0].templateName, "ATG Mobility")
        XCTAssertEqual(preview.workoutSessions[0].sets.first?.exerciseName, "ATG Split Squat")
    }

    func testStrongLiftsImportHandlesExportBOMCRLFAndQuotedFields() throws {
        let csv = "\u{feff}Date (yyyy/mm/dd),Workout,Workout Name,Program Name,Body Weight (LB),Exercise,Sets×Reps,Sets×Time,Top Set (Reps×LB),e1RM (LB),Reps,Volume (LB),Workout Volume (LB),Duration (hours),Start Time (h:mm),End Time (h:mm),Notes,Set 1 (Reps),Set 1 (LB),Set 2 (Reps),Set 2 (LB),Set 3 (Reps),Set 3 (LB),Set 4 (Reps),Set 4 (LB),Set 5 (Reps),Set 5 (LB)\r\n" +
        "2026/03/03,1,\"Workout A\",\"Quarantine\",175,\"Dumbbell Lunge\",5×12,,12×20,31.9,60,2100,9060.0,1.2789,10:02 AM,11:55 AM,\"\",12,20,12,20,12,17.5,12,15,12,15\r\n" +
        "2026/03/03,1,\"Workout A\",\"Quarantine\",175,\"Dumbbell Row\",5×12,,12×30,47.9,60,3600,9060.0,1.2789,10:02 AM,11:55 AM,\"quote \"\"inside\"\" note\",12,30,12,30,12,30,12,30,12,30\r\n"

        let parsed = CSVParser.parse(csv)
        let preview = CSVWorkoutImporter.previewStrongLiftsCSV(csv, sourceFileName: "StrongLifts-export.csv")

        XCTAssertEqual(parsed.count, 3)
        XCTAssertEqual(parsed.first?.first, "Date (yyyy/mm/dd)")
        XCTAssertEqual(preview.rawRecords.count, 2)
        XCTAssertEqual(preview.workoutSessions.count, 1)
        XCTAssertEqual(preview.issues, [])
        XCTAssertEqual(preview.workoutSessions[0].sets.count, 10)
    }

    func testStableIDsAreDeterministicForDedupe() {
        XCTAssertEqual(
            CSVWorkoutImporter.stableID(["a", "b", "c"]),
            CSVWorkoutImporter.stableID(["a", "b", "c"])
        )
        XCTAssertNotEqual(
            CSVWorkoutImporter.stableID(["a", "b", "c"]),
            CSVWorkoutImporter.stableID(["a", "b", "d"])
        )
    }
}
