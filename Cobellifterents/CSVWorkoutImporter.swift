import CryptoKit
import Foundation

enum CSVWorkoutImporter {
    /// Date pickers provide the beginning of the selected day. ATG date ranges
    /// are inclusive, so normalize the upper bound to the final instant of
    /// that day before filtering native sessions.
    static func inclusiveATGEndDate(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))?.addingTimeInterval(-1) ?? date
    }

    static func previewStrongLiftsCSV(_ csv: String, sourceFileName: String) -> ImportPreview {
        let rows = CSVParser.parse(csv)
        guard let header = rows.first else {
            return ImportPreview(sourceKind: .strongLiftsCSV, rawRecords: [], workoutSessions: [], issues: [ImportIssue(rowNumber: 0, message: "CSV is empty")])
        }

        let dictionaries = rows.dropFirst().enumerated().map { index, row in
            CSVParser.dictionary(header: header, row: row, rowNumber: index + 2)
        }

        var issues: [ImportIssue] = []
        var rawRecords: [ImportedRawRecordDraft] = []
        var grouped: [String: [[String: String]]] = [:]
        var inheritedMetadata: [String: String] = [:]
        let groupingFields = ["Date (yyyy/mm/dd)", "Workout", "Workout Name", "Start Time (h:mm)"]

        for dict in dictionaries {
            // StrongLifts exports the workout metadata either on every exercise row or
            // only on the first row of a workout. Treat blank continuation cells as
            // inherited metadata, while retaining the original dictionary in rawJSON.
            var effective = dict
            for field in groupingFields {
                if let value = dict[field], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    inheritedMetadata[field] = value
                } else if let inherited = inheritedMetadata[field] {
                    effective[field] = inherited
                }
            }
            let dateText = effective["Date (yyyy/mm/dd)", default: ""]
            let workoutNumber = effective["Workout", default: ""]
            let workoutName = effective["Workout Name", default: "Imported Workout"]
            let startTime = effective["Start Time (h:mm)", default: ""]
            let rowNumber = Int(dict["__rowNumber", default: "0"]) ?? 0
            let groupID = stableID(["stronglifts", sourceFileName, dateText, workoutNumber, workoutName, startTime])
            // Keep raw-record identity tied to the source row's original metadata so
            // re-import dedupe remains compatible with existing exports.
            let rawGroupID = stableID([
                "stronglifts",
                sourceFileName,
                dict["Date (yyyy/mm/dd)", default: ""],
                dict["Workout", default: ""],
                dict["Workout Name", default: "Imported Workout"],
                dict["Start Time (h:mm)", default: ""]
            ])
            let rawID = stableID([rawGroupID, dict["Exercise", default: ""], String(rowNumber)])
            let occurredAt = parseStrongLiftsDate(dateText, timeText: startTime)

            rawRecords.append(ImportedRawRecordDraft(
                sourceKind: .strongLiftsCSV,
                sourceFileName: sourceFileName,
                sourceRowNumber: rowNumber,
                sourceRecordID: rawID,
                rowJSON: JSONStableEncoder.encode(dict),
                occurredAt: occurredAt
            ))

            guard occurredAt != nil else {
                issues.append(ImportIssue(rowNumber: rowNumber, message: "Could not parse StrongLifts date/time: \(dateText) \(startTime)"))
                continue
            }
            grouped[groupID, default: []].append(effective)
        }

        let sessions = grouped.values.compactMap { rows -> WorkoutSessionDraft? in
            guard let first = rows.first,
                  let startedAt = parseStrongLiftsDate(first["Date (yyyy/mm/dd)", default: ""], timeText: first["Start Time (h:mm)", default: ""]) else {
                return nil
            }
            let completedAt = parseStrongLiftsDate(first["Date (yyyy/mm/dd)", default: ""], timeText: first["End Time (h:mm)", default: ""]) ?? startedAt
            let sourceRecordID = stableID(["stronglifts-session", sourceFileName, first["Date (yyyy/mm/dd)", default: ""], first["Workout", default: ""], first["Workout Name", default: ""], first["Start Time (h:mm)", default: ""]])
            let notes = rows.map { $0["Notes", default: ""] }.filter { !$0.isEmpty }.joined(separator: "\n")
            let sets = rows.flatMap(strongLiftsSets)
            return WorkoutSessionDraft(
                sourceKind: .strongLiftsCSV,
                sourceFileName: sourceFileName,
                sourceRecordID: sourceRecordID,
                templateName: first["Workout Name", default: "Imported Workout"],
                startedAt: startedAt,
                completedAt: completedAt,
                bodyWeight: Double(first["Body Weight (LB)", default: ""]),
                notes: notes,
                sets: sets
            )
        }
        .sorted { $0.startedAt < $1.startedAt }

        return ImportPreview(sourceKind: .strongLiftsCSV, rawRecords: rawRecords, workoutSessions: sessions, issues: issues)
    }

    static func previewATGCSV(_ csv: String, sourceFileName: String, startDate: Date? = nil, endDate: Date? = nil) -> ImportPreview {
        let rows = CSVParser.parse(csv)
        guard let header = rows.first else {
            return ImportPreview(sourceKind: .atgCSV, rawRecords: [], workoutSessions: [], issues: [ImportIssue(rowNumber: 0, message: "CSV is empty")])
        }

        var issues: [ImportIssue] = []
        var rawRecords: [ImportedRawRecordDraft] = []
        var grouped: [String: [[String: String]]] = [:]
        var groupOrder: [String] = []

        for (index, row) in rows.dropFirst().enumerated() {
            let dict = CSVParser.dictionary(header: header, row: row, rowNumber: index + 2)
            let rowNumber = index + 2
            let dateText = dict["date", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
            let occurredAt = parseISODate(dateText)
            // Provenance is independent of whether a row can be converted into a
            // native session. Retain every source row before validating its date or
            // applying the optional native-session range.
            let rawID = stableID(["atg", sourceFileName, String(rowNumber)])
            rawRecords.append(ImportedRawRecordDraft(
                sourceKind: .atgCSV,
                sourceFileName: sourceFileName,
                sourceRowNumber: rowNumber,
                sourceRecordID: rawID,
                rowJSON: JSONStableEncoder.encode(dict),
                occurredAt: occurredAt
            ))
            guard let occurredAt else {
                if !dateText.isEmpty {
                    issues.append(ImportIssue(rowNumber: rowNumber, message: "Could not parse ATG date: \(dateText)"))
                } else {
                    issues.append(ImportIssue(rowNumber: rowNumber, message: "ATG row has no date; preserving raw provenance only"))
                }
                continue
            }
            if let startDate, occurredAt < startDate { continue }
            if let endDate, occurredAt > endDate { continue }
            let workoutType = dict["workout_type", default: "Strength Training"].trimmingCharacters(in: .whitespacesAndNewlines)
            let groupID = stableID(["atg-session", sourceFileName, ISODateOnly.string(from: occurredAt), workoutType])
            if grouped[groupID] == nil { groupOrder.append(groupID) }
            grouped[groupID, default: []].append(dict)
        }

        let sessions = groupOrder.compactMap { groupID -> WorkoutSessionDraft? in
            guard let rows = grouped[groupID] else { return nil }
            guard let first = rows.first, let date = parseISODate(first["date", default: ""]) else { return nil }
            let sourceRecordID = stableID(["atg-session", sourceFileName, ISODateOnly.string(from: date), first["workout_type", default: "Strength Training"]])
            let sets = rows.enumerated().map { offset, row in
                let exerciseName = row["exercise", default: "Exercise"].trimmingCharacters(in: .whitespacesAndNewlines)
                let repsText = row["repetitions", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                let resistanceText = row["resistance", default: ""].trimmingCharacters(in: .whitespacesAndNewlines)
                let groupValue = atgValue(from: row, keys: ["superset", "superset_id", "superset_group", "circuit", "circuit_id", "group"])
                let roundsText = atgValue(from: row, keys: ["rounds", "round_count", "total_rounds", "circuit_rounds"])
                let roundText = atgValue(from: row, keys: ["round", "round_number", "circuit_round"])
                return WorkoutSetDraft(
                    exerciseID: slug(exerciseName),
                    exerciseName: exerciseName,
                    setNumber: offset + 1,
                    targetReps: Int(repsText) ?? 0,
                    completedReps: Int(repsText) ?? 0,
                    weight: Double(resistanceText) ?? 0,
                    durationSeconds: atgDurationSeconds(from: row),
                    note: row["note", default: ""],
                    resistanceUnit: row["resistance_unit"].flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 },
                    weightProvided: Double(resistanceText) != nil,
                    repsProvided: Int(repsText) != nil,
                    supersetGroupID: groupValue.map(slug),
                    roundNumber: roundText.flatMap(Int.init),
                    totalRounds: roundsText.flatMap(Int.init)
                )
            }
            return WorkoutSessionDraft(
                sourceKind: .atgCSV,
                sourceFileName: sourceFileName,
                sourceRecordID: sourceRecordID,
                templateName: "ATG Mobility",
                startedAt: date,
                completedAt: date,
                bodyWeight: nil,
                notes: rows.map { $0["note", default: ""] }.filter { !$0.isEmpty }.joined(separator: "\n"),
                sets: sets,
                programAssignment: inferATGProgram(from: first),
                programAssignmentEvidence: atgProgramEvidence(from: first)
            )
        }
        .sorted { $0.startedAt < $1.startedAt }

        return ImportPreview(sourceKind: .atgCSV, rawRecords: rawRecords, workoutSessions: ATGProgramPlanner.assignPrograms(to: sessions), issues: issues)
    }

    private static func inferATGProgram(from row: [String: String]) -> ImportProgramAssignment {
        guard let value = atgProgramValue(from: row) else { return .unassignedAmbiguous }
        switch slug(value) {
        case "knee_ability_zero": return .kneeAbilityZero
        case "back_ability_zero": return .backAbilityZero
        case "ankle_ability_zero": return .ankleAbilityZero
        default: return .unassignedAmbiguous
        }
    }

    private static func atgProgramValue(from row: [String: String]) -> String? {
        for key in ["program", "program_name", "programName"] {
            if let value = row[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty { return value }
        }
        return nil
    }

    private static func atgProgramEvidence(from row: [String: String]) -> String? {
        atgProgramValue(from: row).map { "Explicit ATG export field: \($0)" }
    }

    private static func atgValue(from row: [String: String], keys: [String]) -> String? {
        keys.lazy.compactMap { row[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
    }

    private static func atgDurationSeconds(from row: [String: String]) -> Int? {
        if let value = atgValue(from: row, keys: ["duration_seconds", "time_seconds"]).flatMap(Double.init), value > 0 { return Int(value.rounded()) }
        if let value = atgValue(from: row, keys: ["duration_minutes", "time_minutes"]).flatMap(Double.init), value > 0 { return Int((value * 60).rounded()) }
        if let value = atgValue(from: row, keys: ["duration_ms", "duration_milliseconds"]).flatMap(Double.init), value > 0 { return Int((value / 1000).rounded()) }
        guard let text = atgValue(from: row, keys: ["duration", "time"])?.lowercased() else { return nil }
        let value = text.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.flatMap { Double($0) }
        guard let value, value > 0 else { return nil }
        if text.contains("min") { return Int((value * 60).rounded()) }
        if text.contains("sec") || text.hasSuffix("s") { return Int(value.rounded()) }
        return nil
    }

    private static func strongLiftsSets(from row: [String: String]) -> [WorkoutSetDraft] {
        let exerciseName = row["Exercise", default: "Exercise"]
        let exerciseID = slug(exerciseName)
        return (1...5).compactMap { setNumber in
            let repsText = row["Set \(setNumber) (Reps)", default: ""]
            let weightText = row["Set \(setNumber) (LB)", default: ""]
            guard !repsText.isEmpty || !weightText.isEmpty else { return nil }
            let reps = Int(Double(repsText) ?? 0)
            return WorkoutSetDraft(
                exerciseID: exerciseID,
                exerciseName: exerciseName,
                setNumber: setNumber,
                targetReps: reps,
                completedReps: reps,
                weight: Double(weightText) ?? 0,
                durationSeconds: nil,
                note: row["Notes", default: ""],
                weightProvided: !weightText.isEmpty,
                repsProvided: !repsText.isEmpty
            )
        }
    }

    private static func parseStrongLiftsDate(_ dateText: String, timeText: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy/MM/dd h:mm a"
        return formatter.date(from: "\(dateText) \(timeText)")
    }

    private static func parseISODate(_ dateText: String) -> Date? {
        guard !dateText.isEmpty else { return nil }
        return ISODateOnly.date(from: dateText)
    }

    static func stableID(_ parts: [String]) -> String {
        let joined = parts.joined(separator: "|")
        let digest = SHA256.hash(data: Data(joined.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func slug(_ value: String) -> String {
        value.lowercased()
            .map { $0.isLetter || $0.isNumber ? String($0) : "_" }
            .joined()
            .split(separator: "_")
            .joined(separator: "_")
    }
}

enum ISODateOnly {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func date(from string: String) -> Date? { formatter.date(from: string) }
    static func string(from date: Date) -> String { formatter.string(from: date) }
}

enum CSVParser {
    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let scalars = Array(text.unicodeScalars)
        var index = 0

        func appendCompletedRow() {
            row.append(field)
            rows.append(row)
            row = []
            field = ""
        }

        while index < scalars.count {
            let scalar = scalars[index]

            if scalar == "\"" {
                if inQuotes,
                   index + 1 < scalars.count,
                   scalars[index + 1] == "\"" {
                    field.append("\"")
                    index += 2
                    continue
                }
                inQuotes.toggle()
            } else if scalar == ",", !inQuotes {
                row.append(field)
                field = ""
            } else if (scalar == "\n" || scalar == "\r"), !inQuotes {
                appendCompletedRow()
                if scalar == "\r",
                   index + 1 < scalars.count,
                   scalars[index + 1] == "\n" {
                    index += 1
                }
            } else if scalar != "\u{feff}" || !rows.isEmpty || !row.isEmpty || !field.isEmpty {
                field.unicodeScalars.append(scalar)
            }

            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    static func dictionary(header: [String], row: [String], rowNumber: Int) -> [String: String] {
        var result: [String: String] = ["__rowNumber": String(rowNumber)]
        for (index, key) in header.enumerated() {
            result[normalizedHeaderKey(key)] = index < row.count ? row[index] : ""
        }
        return result
    }

    private static func normalizedHeaderKey(_ key: String) -> String {
        key.trimmingCharacters(in: CharacterSet(charactersIn: "\u{feff}"))
    }
}

enum JSONStableEncoder {
    static func encode(_ dictionary: [String: String]) -> String {
        let pairs = dictionary.keys.sorted().map { key in
            "\(quote(key)):\(quote(dictionary[key, default: ""]))"
        }
        return "{\(pairs.joined(separator: ","))}"
    }

    private static func quote(_ string: String) -> String {
        let data = try? JSONSerialization.data(withJSONObject: [string])
        let encoded = String(data: data ?? Data("[\"\"]".utf8), encoding: .utf8) ?? "[\"\"]"
        return String(encoded.dropFirst().dropLast())
    }
}
