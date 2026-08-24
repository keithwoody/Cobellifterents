import CryptoKit
import Foundation

enum CSVWorkoutImporter {
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

        for dict in dictionaries {
            let dateText = dict["Date (yyyy/mm/dd)", default: ""]
            let workoutNumber = dict["Workout", default: ""]
            let workoutName = dict["Workout Name", default: "Imported Workout"]
            let startTime = dict["Start Time (h:mm)", default: ""]
            let rowNumber = Int(dict["__rowNumber", default: "0"]) ?? 0
            let groupID = stableID(["stronglifts", sourceFileName, dateText, workoutNumber, workoutName, startTime])
            let rawID = stableID([groupID, dict["Exercise", default: ""], String(rowNumber)])
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
            grouped[groupID, default: []].append(dict)
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

    static func previewATGCSV(_ csv: String, sourceFileName: String) -> ImportPreview {
        let rows = CSVParser.parse(csv)
        guard let header = rows.first else {
            return ImportPreview(sourceKind: .atgCSV, rawRecords: [], workoutSessions: [], issues: [ImportIssue(rowNumber: 0, message: "CSV is empty")])
        }

        var issues: [ImportIssue] = []
        var rawRecords: [ImportedRawRecordDraft] = []
        var grouped: [String: [[String: String]]] = [:]

        for (index, row) in rows.dropFirst().enumerated() {
            let dict = CSVParser.dictionary(header: header, row: row, rowNumber: index + 2)
            let rowNumber = index + 2
            let dateText = dict["date", default: ""]
            let occurredAt = parseISODate(dateText)
            let rawID = stableID(["atg", sourceFileName, String(rowNumber), dict["exercise", default: ""], dateText, dict["repetitions", default: ""], dict["duration_seconds", default: ""], dict["note", default: ""]])
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
            let groupID = stableID(["atg-session", sourceFileName, ISODateOnly.string(from: occurredAt), dict["workout_type", default: "Strength Training"]])
            grouped[groupID, default: []].append(dict)
        }

        let sessions = grouped.values.compactMap { rows -> WorkoutSessionDraft? in
            guard let first = rows.first, let date = parseISODate(first["date", default: ""]) else { return nil }
            let sourceRecordID = stableID(["atg-session", sourceFileName, ISODateOnly.string(from: date), first["workout_type", default: "Strength Training"]])
            let sets = rows.enumerated().map { offset, row in
                WorkoutSetDraft(
                    exerciseID: slug(row["exercise", default: "exercise"]),
                    exerciseName: row["exercise", default: "Exercise"],
                    setNumber: offset + 1,
                    targetReps: Int(row["repetitions", default: ""]) ?? 0,
                    completedReps: Int(row["repetitions", default: ""]) ?? 0,
                    weight: Double(row["resistance", default: ""]) ?? 0,
                    durationSeconds: Int(row["duration_seconds", default: ""]),
                    note: row["note", default: ""]
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
                sets: sets
            )
        }
        .sorted { $0.startedAt < $1.startedAt }

        return ImportPreview(sourceKind: .atgCSV, rawRecords: rawRecords, workoutSessions: sessions, issues: issues)
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
                note: row["Notes", default: ""]
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
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if inQuotes, let next = iterator.next() {
                    if next == "\"" {
                        field.append("\"")
                    } else {
                        inQuotes = false
                        if next == "," {
                            row.append(field)
                            field = ""
                        } else if next == "\n" {
                            row.append(field)
                            rows.append(row)
                            row = []
                            field = ""
                        } else if next != "\r" {
                            field.append(next)
                        }
                    }
                } else {
                    inQuotes.toggle()
                }
            } else if character == ",", !inQuotes {
                row.append(field)
                field = ""
            } else if character == "\n", !inQuotes {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
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
            result[key] = index < row.count ? row[index] : ""
        }
        return result
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
