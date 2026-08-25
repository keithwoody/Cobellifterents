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

    func testATGImportPreservesOrderMetadataAndRejectsAmbiguousDates() {
        let csv = "\u{feff}workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\r\n" +
            "Strength Training,\"ATG Pushup\",2024-01-11,10,0,lbs,30,30000,\"slow tempo\"\r\n" +
            "Strength Training,ATG Split Squat,2024-01-11,5,20,lbs,0,0,\r\n" +
            "Strength Training,ATG Pushup,,8,0,lbs,20,20000,\r\n" +
            "Strength Training,ATG Row,not-a-date,8,10,lbs,0,0,\r\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG-export.csv")
        XCTAssertEqual(preview.rawRecords.count, 4)
        XCTAssertEqual(preview.workoutSessions.count, 1)
        XCTAssertEqual(preview.issues.map(\.rowNumber), [4, 5])
        XCTAssertEqual(preview.workoutSessions[0].sets.map(\.exerciseName), ["ATG Pushup", "ATG Split Squat"])
        XCTAssertEqual(preview.workoutSessions[0].sets[0].durationSeconds, 30)
        XCTAssertEqual(preview.workoutSessions[0].sets[0].note, "slow tempo")
        XCTAssertNil(preview.rawRecords[2].occurredAt)
        XCTAssertTrue(preview.rawRecords[0].rowJSON.contains("slow tempo"))
    }

    func testATGSessionGroupingUsesDateAndWorkoutTypeWithoutInventingBoundaries() {
        let csv = "workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Mobility,Move A,2024-01-11,1,,,,,\n" +
            "Mobility,Move B,2024-01-11,2,,,,,\n" +
            "Strength Training,Move C,2024-01-11,3,,,,,\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")
        XCTAssertEqual(preview.workoutSessions.count, 2)
        XCTAssertEqual(preview.workoutSessions.map { $0.sets.map(\.exerciseName) }, [["Move A", "Move B"], ["Move C"]])
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

    func testStrongLiftsExportWithBlankContinuationMetadataInfersFourExercisesPerWorkout() {
        let header = "Date (yyyy/mm/dd),Workout,Workout Name,Program Name,Body Weight (LB),Exercise,Sets×Reps,Sets×Time,Top Set (Reps×LB),e1RM (LB),Reps,Volume (LB),Workout Volume (LB),Duration (hours),Start Time (h:mm),End Time (h:mm),Notes,Set 1 (Reps),Set 1 (LB),Set 2 (Reps),Set 2 (LB),Set 3 (Reps),Set 3 (LB),Set 4 (Reps),Set 4 (LB),Set 5 (Reps),Set 5 (LB)"
        func row(_ date: String, _ number: String, _ name: String, _ exercise: String, _ reps: String, _ weight: String) -> String {
            var fields = Array(repeating: "", count: 27)
            fields[0] = date
            fields[1] = number
            fields[2] = name
            fields[3] = "Quarantine"
            fields[4] = "175"
            fields[5] = exercise
            fields[6] = "5×\(reps)"
            fields[8] = "\(reps)×\(weight)"
            fields[10] = "25"
            fields[14] = "10:02 AM"
            fields[15] = "11:55 AM"
            for setNumber in 0..<5 {
                fields[17 + setNumber * 2] = reps
                fields[18 + setNumber * 2] = weight
            }
            return fields.joined(separator: ",")
        }
        let csv = ([header,
                    row("2026/03/03", "1", "Workout A", "Squat", "5", "135"),
                    row("", "", "", "Bench Press", "5", "100"),
                    row("", "", "", "Barbell Row", "5", "95"),
                    row("", "", "", "Overhead Press", "5", "65"),
                    row("2026/03/05", "2", "Workout B", "Deadlift", "5", "185"),
                    row("", "", "", "Squat", "5", "140"),
                    row("", "", "", "Bench Press", "5", "102.5"),
                    row("", "", "", "Barbell Row", "5", "97.5")]).joined(separator: "\n")

        let preview = CSVWorkoutImporter.previewStrongLiftsCSV(csv, sourceFileName: "StrongLifts.csv")
        XCTAssertEqual(preview.rawRecords.count, 8)
        XCTAssertEqual(preview.workoutSessions.count, 2)
        XCTAssertEqual(preview.workoutSessions.map { $0.sets.count }, [20, 20])
        XCTAssertEqual(preview.issues, [])

        let inferred = ImportToProgramInference.infer(from: preview.workoutSessions, sourceKind: .strongLiftsCSV)!
        XCTAssertEqual(inferred.program.workouts.map(\.identity), ["A", "B"])
        XCTAssertEqual(inferred.program.workouts.map { $0.exercises.map(\.name) }, [
            ["Squat", "Bench Press", "Barbell Row", "Overhead Press"],
            ["Deadlift", "Squat", "Bench Press", "Barbell Row"]
        ])
        XCTAssertEqual(inferred.program.workouts.flatMap { $0.exercises }.map(\.targetSets), Array(repeating: 5, count: 8))
        XCTAssertEqual(inferred.program.workouts.flatMap { $0.exercises }.map(\.targetReps), Array(repeating: 5, count: 8))
    }

    func testATGImportPreservesAllRowsWhenNativeSessionDateRangeIsApplied() {
        let csv = "workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Strength Training,Before,2024-01-10,1,,,,,\n" +
            "Strength Training,In Range,2024-01-11,2,,,,,\n" +
            "Strength Training,After,2024-01-13,3,,,,,\n" +
            "Strength Training,Blank,,4,,,,,\n" +
            "Strength Training,Invalid,not-a-date,5,,,,,\n"
        let start = ISODateOnly.date(from: "2024-01-11")!
        let end = ISODateOnly.date(from: "2024-01-12")!
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv", startDate: start, endDate: end)

        XCTAssertEqual(preview.rawRecords.count, 5)
        XCTAssertEqual(preview.rawRecords.map(\.sourceRowNumber), [2, 3, 4, 5, 6])
        XCTAssertEqual(preview.rawRecords.map { $0.occurredAt != nil }, [true, true, true, false, false])
        XCTAssertEqual(preview.workoutSessions.count, 1)
        XCTAssertEqual(preview.workoutSessions[0].sets.map(\.exerciseName), ["In Range"])
        XCTAssertEqual(preview.issues.map(\.rowNumber), [5, 6])
    }

    func testATGInclusiveEndDateIncludesEndDayAndPreservesOutOfRangeRawRows() {
        let csv = "workout_type,exercise,date,repetitions\n" +
            "Strength Training,Before,2024-01-10,1\n" +
            "Strength Training,End Day,2024-01-12,2\n" +
            "Strength Training,After,2024-01-13,3\n"
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = ISODateOnly.date(from: "2024-01-11")!
        let end = ISODateOnly.date(from: "2024-01-12")!
        let preview = CSVWorkoutImporter.previewATGCSV(
            csv,
            sourceFileName: "ATG.csv",
            startDate: start,
            endDate: CSVWorkoutImporter.inclusiveATGEndDate(end, calendar: calendar)
        )

        XCTAssertEqual(preview.rawRecords.map(\.sourceRowNumber), [2, 3, 4])
        XCTAssertEqual(preview.workoutSessions.map { $0.sets.map(\.exerciseName) }, [["End Day"]])
    }

    func testATGProgramAssignmentRequiresExplicitEvidence() {
        let csv = "workout_type,exercise,date,repetitions,resistance,resistance_unit,duration_seconds,duration_ms,note\n" +
            "Strength Training,Monday Original,2024-01-01,1,,,,,\n" +
            "Strength Training,Tuesday Stable,2024-01-02,1,,,,,\n" +
            "Strength Training,Monday Changed,2024-01-08,1,,,,,\n" +
            "Strength Training,Latest,2024-01-20,1,,,,,\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")
        let assignments = Dictionary(uniqueKeysWithValues: preview.workoutSessions.map { (ISODateOnly.string(from: $0.startedAt), $0.programAssignment) })

        XCTAssertTrue(assignments.values.allSatisfy { $0 == .unassignedAmbiguous })
        XCTAssertTrue(preview.workoutSessions.allSatisfy { $0.programAssignmentEvidence == nil })
    }

    func testATGProgramAssignmentPreservesExplicitSupportedIdentity() {
        let csv = "workout_type,program,exercise,date,repetitions\n" +
            "Strength Training,Ankle Ability Zero,Calf Raise,2024-01-20,5\n" +
            "Strength Training,Back Ability Zero,Back Extension,2024-01-21,5\n" +
            "Strength Training,Unknown Plan,Move,2024-01-22,5\n"
        let preview = CSVWorkoutImporter.previewATGCSV(csv, sourceFileName: "ATG.csv")

        XCTAssertEqual(preview.workoutSessions.map(\.programAssignment), [.ankleAbilityZero, .backAbilityZero, .unassignedAmbiguous])
        XCTAssertEqual(preview.workoutSessions[0].programAssignmentEvidence, "Explicit ATG export field: Ankle Ability Zero")
        XCTAssertEqual(preview.workoutSessions[2].programAssignmentEvidence, "Explicit ATG export field: Unknown Plan")
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
