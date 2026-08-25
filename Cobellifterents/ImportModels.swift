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

enum ImportProgramAssignment: String, Codable, Equatable {
    case unassignedAmbiguous
    case kneeAbilityZero
    case backAbilityZero
    case ankleAbilityZero

    var displayName: String {
        switch self {
        case .unassignedAmbiguous: return "Unassigned (program unclear)"
        case .kneeAbilityZero: return "Knee Ability Zero"
        case .backAbilityZero: return "Back Ability Zero"
        case .ankleAbilityZero: return "Ankle Ability Zero"
        }
    }
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
    let programAssignment: ImportProgramAssignment
    let programAssignmentEvidence: String?

    init(sourceKind: ImportSourceKind, sourceFileName: String, sourceRecordID: String, templateName: String, startedAt: Date, completedAt: Date, bodyWeight: Double?, notes: String, sets: [WorkoutSetDraft], programAssignment: ImportProgramAssignment = .unassignedAmbiguous, programAssignmentEvidence: String? = nil) {
        self.sourceKind = sourceKind
        self.sourceFileName = sourceFileName
        self.sourceRecordID = sourceRecordID
        self.templateName = templateName
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.bodyWeight = bodyWeight
        self.notes = notes
        self.sets = sets
        self.programAssignment = programAssignment
        self.programAssignmentEvidence = programAssignmentEvidence
    }
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
    let resistanceUnit: String?

    init(exerciseID: String, exerciseName: String, setNumber: Int, targetReps: Int, completedReps: Int, weight: Double, durationSeconds: Int?, note: String, resistanceUnit: String? = nil) {
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.setNumber = setNumber
        self.targetReps = targetReps
        self.completedReps = completedReps
        self.weight = weight
        self.durationSeconds = durationSeconds
        self.note = note
        self.resistanceUnit = resistanceUnit
    }
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
    static func importedSession(from draft: WorkoutSessionDraft, programAssignmentID: UUID? = nil) -> WorkoutSession {
        let templateID: TemplateID
        if draft.sourceKind == .atgCSV {
            templateID = .atgImported
        } else {
            templateID = draft.templateName == "Workout B" ? .strongLiftsB : .strongLiftsA
        }
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
        session.programAssignmentRawValue = draft.programAssignment.rawValue
        session.programAssignmentEvidence = draft.programAssignmentEvidence
        session.programAssignmentID = programAssignmentID
        var exerciseOrderByID: [String: Int] = [:]
        session.sets = draft.sets.map { set in
            let displayOrder = exerciseOrderByID[set.exerciseID] ?? exerciseOrderByID.count
            exerciseOrderByID[set.exerciseID] = displayOrder
            let record = WorkoutSetRecord(
                exerciseID: set.exerciseID,
                exerciseName: set.exerciseName,
                setNumber: set.setNumber,
                displayOrder: displayOrder,
                targetReps: set.targetReps,
                completedReps: set.completedReps,
                weight: set.weight,
                isComplete: set.completedReps > 0
            )
            record.durationSeconds = set.durationSeconds
            record.notes = set.note
            record.resistanceUnit = set.resistanceUnit
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
