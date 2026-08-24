import Foundation
import SwiftData

enum ImportSourceKind: String, Codable, CaseIterable {
    case strongLiftsCSV
    case atgCSV
}

struct ImportIssue: Equatable {
    let rowNumber: Int
    let message: String
}

struct ImportPreview: Equatable {
    let sourceKind: ImportSourceKind
    let rawRecords: [ImportedRawRecordDraft]
    let workoutSessions: [WorkoutSessionDraft]
    let issues: [ImportIssue]
}

struct ImportedRawRecordDraft: Equatable {
    let sourceKind: ImportSourceKind
    let sourceFileName: String
    let sourceRowNumber: Int
    let sourceRecordID: String
    let rowJSON: String
    let occurredAt: Date?
}

struct WorkoutSessionDraft: Equatable {
    let sourceKind: ImportSourceKind
    let sourceFileName: String
    let sourceRecordID: String
    let templateName: String
    let startedAt: Date
    let completedAt: Date
    let bodyWeight: Double?
    let notes: String
    let sets: [WorkoutSetDraft]
}

struct WorkoutSetDraft: Equatable {
    let exerciseID: String
    let exerciseName: String
    let setNumber: Int
    let targetReps: Int
    let completedReps: Int
    let weight: Double
    let durationSeconds: Int?
    let note: String
}

@Model
final class ImportedRawRecord {
    @Attribute(.unique) var sourceRecordID: String
    var sourceKindRawValue: String
    var sourceFileName: String
    var sourceRowNumber: Int
    var rowJSON: String
    var occurredAt: Date?
    var importedAt: Date

    init(sourceKind: ImportSourceKind, sourceFileName: String, sourceRowNumber: Int, sourceRecordID: String, rowJSON: String, occurredAt: Date?, importedAt: Date = Date()) {
        self.sourceKindRawValue = sourceKind.rawValue
        self.sourceFileName = sourceFileName
        self.sourceRowNumber = sourceRowNumber
        self.sourceRecordID = sourceRecordID
        self.rowJSON = rowJSON
        self.occurredAt = occurredAt
        self.importedAt = importedAt
    }
}

enum WorkoutImportMapper {
    static func importedSession(from draft: WorkoutSessionDraft) -> WorkoutSession {
        let templateID: TemplateID = draft.templateName == "Workout B" ? .strongLiftsB : .strongLiftsA
        let session = WorkoutSession(
            templateID: templateID,
            templateName: draft.templateName,
            startedAt: draft.startedAt,
            completedAt: draft.completedAt
        )
        session.importSourceKindRawValue = draft.sourceKind.rawValue
        session.importSourceFileName = draft.sourceFileName
        session.importSourceRecordID = draft.sourceRecordID
        session.bodyWeight = draft.bodyWeight
        session.notes = draft.notes
        session.sets = draft.sets.map { set in
            let record = WorkoutSetRecord(
                exerciseID: set.exerciseID,
                exerciseName: set.exerciseName,
                setNumber: set.setNumber,
                targetReps: set.targetReps,
                completedReps: set.completedReps,
                weight: set.weight,
                isComplete: set.completedReps > 0
            )
            record.durationSeconds = set.durationSeconds
            record.notes = set.note
            return record
        }
        return session
    }

    static func importedRawRecord(from draft: ImportedRawRecordDraft) -> ImportedRawRecord {
        ImportedRawRecord(
            sourceKind: draft.sourceKind,
            sourceFileName: draft.sourceFileName,
            sourceRowNumber: draft.sourceRowNumber,
            sourceRecordID: draft.sourceRecordID,
            rowJSON: draft.rowJSON,
            occurredAt: draft.occurredAt
        )
    }
}
